$Params =
@{
	TranslationsPerLanguage = (& "$PSScriptRoot\@Get-StringResourceTranslation.ps1")
}



& "$PSScriptRoot\..\..\_Util\Functions\@ConvertTo-AndroidStringResourceFormat.ps1" @Params