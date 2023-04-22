$Params =
@{
	TranslationsPerLanguage = (& "$PSScriptRoot\@Get-StringResourceTranslation.ps1")
}



& "$PSScriptRoot\..\..\_Util\Functions\@ConvertTo-IosStringResourceFormat.ps1" @Params