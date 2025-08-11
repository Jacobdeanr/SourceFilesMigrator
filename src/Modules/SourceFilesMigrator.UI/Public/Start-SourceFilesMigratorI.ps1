function Start-SourceFilesMigratorUI {
    [CmdletBinding()]
    param(
        [string]$InitialDestination = (Join-Path (Get-Location) "package")
    )

    # WPF requires STA
    $apt = [System.Threading.Thread]::CurrentThread.ApartmentState
    if ($apt -ne [System.Threading.ApartmentState]::STA) {
        throw "This UI must run in STA. Launch PowerShell with -STA or run via Start-SourceFilesMigrator.ps1."
    }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase | Out-Null
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms | Out-Null

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SourceFilesMigrator - Drop Assets" Height="720" Width="1280"
        WindowStartupLocation="CenterScreen" Background="#1E1E1E" Foreground="#FFFFFF">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="180"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Destination -->
    <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
      <TextBlock Text="Destination Project Path:" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <TextBox x:Name="DestText" Width="600" Margin="0,0,8,0"/>
      <Button x:Name="BrowseBtn" Content="Browse..." Width="90"/>
      <CheckBox x:Name="IncludeVtfsCb" Foreground="White" Content="Include VTFs" Margin="16,0,0,0" IsChecked="True"/>
      <CheckBox x:Name="DryRunCb" Foreground="White" Content="Dry Run" Margin="12,0,0,0" IsChecked="False"/>
    </StackPanel>

    <!-- Drop zone -->
    <Border Grid.Row="1" Background="#2b2b2b" Padding="12" AllowDrop="True" x:Name="DropZone">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock Text="Drag &amp; Drop files or folders here" FontSize="16" FontWeight="Bold" Margin="0,6" />
        <TextBlock Text="Supported: .mdl, .vmt, .vtf, or folders (we'll auto-route contents)" Opacity="0.7"/>
      </StackPanel>
    </Border>

    <!-- Queue -->
    <GroupBox Grid.Row="2" Header="Queue" BorderThickness="0" Background="#2b2b2b" Foreground="#E5E7EB">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <ListView x:Name="QueueList" Grid.Column="0" Margin="6" SelectionMode="Extended">
          <ListView.View>
            <GridView>
              <GridViewColumn Header="Type" Width="90" DisplayMemberBinding="{Binding Kind}"/>
              <GridViewColumn Header="Path" Width="560" DisplayMemberBinding="{Binding Path}"/>
            </GridView>
          </ListView.View>
        </ListView>

        <StackPanel Grid.Column="1" Margin="6" Orientation="Vertical">
          <Button x:Name="RemoveBtn" Content="Remove Selected" Margin="0,0,0,6" Width="140"/>
          <Button x:Name="ClearBtn" Content="Clear All" Margin="0,0,0,6" Width="140"/>
          <Button x:Name="ProcessSelBtn" Content="Process Selected" Margin="0,0,0,6" Width="140"/>
          <Button x:Name="ProcessAllBtn" Content="Process All" Margin="0,0,0,6" Width="140"/>
        </StackPanel>
      </Grid>
    </GroupBox>

    <!-- Log -->
    <GroupBox Grid.Row="3" Header="Log" BorderThickness="0" Background="#2b2b2b" Foreground="#E5E7EB" Margin="0,12,0,0">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="6">
        <TextBox x:Name="LogBox" TextWrapping="Wrap" AcceptsReturn="True" IsReadOnly="True" Height="150" Background="#2b2b2b" Foreground="#E5E7EB"/>
      </ScrollViewer>
    </GroupBox>

    <!-- Footer -->
    <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button x:Name="CloseBtn" Content="Close" Width="90"/>
    </StackPanel>
  </Grid>
</Window>
"@

    # Simpler parse path avoids XmlReader ambiguity and encoding pitfalls
    try {
        $window = [System.Windows.Markup.XamlReader]::Parse($xaml)
    } catch {
        throw "Failed to parse XAML: $($_.Exception.Message)"
    }

    # Find controls
    $DestText       = $window.FindName('DestText')
    $BrowseBtn      = $window.FindName('BrowseBtn')
    $IncludeVtfsCb  = $window.FindName('IncludeVtfsCb')
    $DryRunCb       = $window.FindName('DryRunCb')
    $DropZone       = $window.FindName('DropZone')
    $QueueList      = $window.FindName('QueueList')
    $RemoveBtn      = $window.FindName('RemoveBtn')
    $ClearBtn       = $window.FindName('ClearBtn')
    $ProcessSelBtn  = $window.FindName('ProcessSelBtn')
    $ProcessAllBtn  = $window.FindName('ProcessAllBtn')
    $LogBox         = $window.FindName('LogBox')
    $CloseBtn       = $window.FindName('CloseBtn')

    $DestText.Text = $InitialDestination

    # Backing collection
    $items = New-Object System.Collections.ObjectModel.ObservableCollection[pscustomobject]
    $QueueList.ItemsSource = $items

    function Append-Log([string]$text) {
        $LogBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $text`r`n")
        $LogBox.ScrollToEnd()
    }

    # Browse for destination
    $BrowseBtn.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Select destination project root"
        try {
            $dlg.SelectedPath = if (Test-Path $DestText.Text) { (Resolve-Path $DestText.Text).Path } else { (Get-Location).Path }
        } catch {
            $dlg.SelectedPath = (Get-Location).Path
        }
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $DestText.Text = $dlg.SelectedPath
        }
    })

    # Drag-over: accept files/folders
    $DropZone.Add_DragOver({
        if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
            $_.Effects = [Windows.DragDropEffects]::Copy
        } else {
            $_.Effects = [Windows.DragDropEffects]::None
        }
        $_.Handled = $true
    })

    # Import helper functions from UI.Private if not already in scope
    if (-not (Get-Command Filter-Path -ErrorAction SilentlyContinue)) {
        # Private functions are already dot-sourced by the module .psm1; this is just a safety net.
    }

    # Drop handler
    $DropZone.Add_Drop({
        if (-not $_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }
        $paths = @($_.Data.GetData([Windows.DataFormats]::FileDrop))
        foreach ($p in $paths) {
            if ([string]::IsNullOrWhiteSpace($p)) { continue }
            $full = try { (Resolve-Path -LiteralPath $p).Path } catch { $p }
            if (Filter-Path -Path $full) {
                Append-Log "Skipped by exclude rules: $full"
                continue
            }
            $kind = Get-DroppedItemKind -Path $full
            $items.Add([pscustomobject]@{ Kind=$kind; Path=$full }) | Out-Null
            Append-Log "Queued: [$kind] $full"
        }
    })

    # Remove selected
    $RemoveBtn.Add_Click({
        $sel = @($QueueList.SelectedItems)
        foreach ($s in $sel) { [void]$items.Remove($s) }
        Append-Log "Removed $($sel.Count) item(s)."
    })

    # Clear all
    $ClearBtn.Add_Click({
        $items.Clear()
        Append-Log "Cleared queue."
    })

    function Process-Entries([System.Collections.IEnumerable]$entries) {
      $dest = $DestText.Text
      if ([string]::IsNullOrWhiteSpace($dest)) {
          [System.Windows.MessageBox]::Show("Please set a destination path.", "SourceFilesMigrator")
          return
      }
      Test-Directory -Path $dest | Out-Null
  
      $incVtf = [bool]$IncludeVtfsCb.IsChecked
      $dry    = [bool]$DryRunCb.IsChecked
  
      Append-Log "Processing batch (IncludeVTFs=$incVtf, DryRun=$dry) ..."
      $result = Invoke-SourceFilesMigratorEntries -Entries $entries `
                                         -DestinationProjectRoot $dest `
                                         -IncludeVtfs:$incVtf -DryRun:$dry -Verbose
      $s = $result.Summary
      Append-Log ("Batch complete: Models=$($s.UniqueModelsProcessed);
       VMTs planned=$($s.UniqueVMTsPlanned);
       VTFs planned=$($s.UniqueVTFsPlanned);
       Model files copied=$($s.ModelFilesCopied);
       VMT files copied=$($s.VmtFilesCopied);
       VTF files copied=$($s.VtfFilesCopied)")
    }
  

    $ProcessSelBtn.Add_Click({
        $sel = @($QueueList.SelectedItems)
        if ($sel.Count -eq 0) { Append-Log "Nothing selected."; return }
        Process-Entries -entries $sel
    })

    $ProcessAllBtn.Add_Click({
        Process-Entries -entries $items
    })

    $CloseBtn.Add_Click({ $window.Close() })

    $window.Add_SourceInitialized({ Append-Log "Ready. Drag & drop files or folders. Default: Dry Run ON." })
    $window.ShowDialog() | Out-Null
}