$projectPath = "D:\Todo\Documentos\Git\AndroidStudio\PadelManager"

$mainPackagePath = "$projectPath/app/src/main/java/com/padelmanager/padelmanager"

#region Tools

enum Reemplacement
{
    Witout2ToWith2
    With2ToWithout2
}

function ReplaceContent($Object, [Reemplacement] $Reemplacement)
{
    $contenido = Get-Content $object.path -Raw

    $nuevoContenido = switch ($Reemplacement)
    {
        Witout2ToWith2 { $contenido.Replace($object.without2, $object.with2) }
        With2ToWithout2 { $contenido.Replace($object.with2, $object.without2) }
    }

    Set-Content $object.path -Value $nuevoContenido -NoNewline -Force -ErrorAction SilentlyContinue
}

function ReplaceContentInList($List, [Reemplacement] $Reemplacement)
{
    foreach ($object in $List)
    {
        ReplaceContent -Object $object -Reemplacement $Reemplacement
    }
}

#endregion

$reservationsFolder = "$mainPackagePath/v2/ui/booking/fragment"

$findWithout2 = 'findNavController().navigate(FragmentNewReservationClubsDirections.actionFragmentNewReservationClubsToFragmentReservations())'
$findWith2    = 'findNavController().navigate(FragmentNewReservationClubsDirections.actionFragmentNewReservationClubsToFragmentReservations2())'

# This is for files that the content to replace is $findWithout2 or $findWith2
$objectBase =
@{
    without2 = $findWithout2
    with2    = $findWith2
}


$navGraph = 
@{
    path     = "$projectPath/app/src/main/res/navigation/nav_graph.xml"
    without2 = 'android:id="@+id/action_fragmentNewReservationClubs_to_fragmentReservations"'
    with2    = 'android:id="@+id/action_fragmentNewReservationClubs_to_fragmentReservations2"'
}

# In case you have a file that doen't use $findWithout2 and $findWith2 then added in here (like $navGraph)
$specialFileObjects =
@(
    $navGraph
)

# In case you want to add more files like the object base type just add its path here
$listOfPaths =
@(
    "$reservationsFolder/FragmentNewReservationClubs.kt",
    "$reservationsFolder/FragmentNewReservationDetails.kt"#,
    # "$mainPackagePath/v2/ui/booking/adapters/CourtsAdapter.kt"
)

#region Execution

$listOfPathToObjects = foreach($path in $listOfPaths)
{
    $objectBase + @{ path = $path }
}

$pathsWithDataToReplaceList = $specialFileObjects + $listOfPathToObjects


$navGraphContent = Get-Content $navGraph.path -Raw

if ($navGraphContent.Contains($navGraph.without2))
{
    ReplaceContentInList -List $pathsWithDataToReplaceList -Reemplacement Witout2ToWith2
}
elseif ($navGraphContent.Contains($navGraph.with2))
{
    ReplaceContentInList -List $pathsWithDataToReplaceList -Reemplacement With2ToWithout2
}

#endregion