param([string]$Library='H:/Game/3DModels')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ignore=Join-Path $project 'assets/local_source/.gdignore'
if(Test-Path -LiteralPath $ignore) { Remove-Item -LiteralPath $ignore }
$packs=@{
 'POLYGON_Farm/POLYGON_Farm_Godot_4_6_2_v1_0_0.zip'=@('SM_Bld_Farmhouse_01','SM_Bld_Farmhouse_02','SM_Bld_Barn_02','SM_Generic_Tree_01','SM_Generic_Tree_02','SM_Veh_Pickup_01')
 'POLYGON_Starter/POLYGON_Starter_Godot_4_6_2_v1_1_0.zip'=@('SM_PolygonCity_Veh_Car_Small_01','SM_Bean_Female_01','SM_Bean_Town_Female_01','SM_Bean_Cowboy_01')
}
foreach($pack in $packs.Keys) {
 $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $Library $pack))
 try {
  $entries=@{}
  foreach($entry in $zip.Entries) {
   if($entry.FullName -match '(?i)/assets/synty/(.+)$') { $entries[$Matches[1]]=$entry }
  }
  $seen=@{}
  function Copy-Dependency([string]$key) {
   if($seen.ContainsKey($key)) { return }
   if(!$entries.ContainsKey($key)) { throw "Missing dependency: $key" }
   $seen[$key]=$true
   $entry=$entries[$key]
   $relative=$entry.FullName -replace '(?i)^.*?/assets/synty/',''
   $destination=Join-Path $project ('assets/local_source/'+$relative)
   [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
   if($relative -match '\.(tscn|tres)$') {
    $reader=[IO.StreamReader]::new($entry.Open())
    $content=$reader.ReadToEnd(); $reader.Dispose()
    $dependencies=[regex]::Matches($content,'(?i)res://assets/synty/([^"\r\n]+)')
    foreach($dependency in $dependencies) { Copy-Dependency $dependency.Groups[1].Value }
    $content=[regex]::Replace($content,'(?i)res://assets/synty/([^"\r\n]+)',{param($m) 'res://assets/local_source/'+($entries[$m.Groups[1].Value].FullName -replace '(?i)^.*?/assets/synty/','')})
    $content=[regex]::Replace($content,' uid="uid://[^"]+"','')
    [IO.File]::WriteAllText($destination,$content)
   } else { [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$true) }
  }
  foreach($name in $packs[$pack]) {
   $key=$entries.Keys | Where-Object {$_ -match ('/Prefabs/(?:.*/)?'+[regex]::Escape($name)+'\.tscn$')} | Select-Object -First 1
   if(!$key) { throw "Missing prefab: $name" }
   Copy-Dependency $key
  }
  Write-Output "$pack : $($seen.Count) files imported"
 } finally { $zip.Dispose() }
}
