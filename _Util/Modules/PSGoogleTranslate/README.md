# PSGoogleTranslate

<h3>A PowerShell module to easily use the free Google Translate API.</h3>

## How to use

The module only consists of only one function:

~~~PowerShell
Invoke-GoogleTranslate
~~~

The basic functionality is to translate one text from a source language to a target language, but you can do many more things by specifying the **$ReturnType** of the function.

Before explaining all the posibilities let's see how the basic functionality works:

- First you introduce a text in the **$InputObject** parameter.
- You can then specicify the **$SourceLanguage**, it both accepts the English word name and the language code.
The default value is **auto**.
- Then the **$TargetLangauge**, it's pretty much the same as before.

Example:
~~~PowerShell
Invoke-GoogleTranslate -InputObject "Hoy vi un ciervo" -SourceLanguage Spanish -TargetLanguage English

# Output:
# SourceLanguage Translation
# -------------- -----------
# es             I saw a deer today
~~~
<br>

Now that we understand the basic functionality let's explore the other types of return values.

 These are all the possible values for the **$ReturnType** parameter:
- **Translation** (default):  given some text  returns an object with the translation and the source language.
- **Alternative**: given some text  returns and object with the source language and the alternatives translations per line:
~~~PowerShell
$response = Invoke-GoogleTranslate -ReturnType Alternative -InputObject "Hoy vi un ciervo`nDemasiado helado por hoy" -SourceLanguage Spanish -TargetLanguage English

$response.SourceLanguage
# es

$response.AlternativesPerLine
# SourceLine               TranslationAlternatives
# ----------               -----------------------
# Demasiado helado por hoy {Too much ice cream for today, Too much ice cream today}
# Hoy vi un ciervo         {I saw a deer today, today i saw a deer}
~~~

- **DetectedLanguage**: given some text returns the language code of the detected language.
- **DetectedLanguageAsEnglishWord**: given some text returns the language name in English of the detected language.
- **Dictionary**: given a word (it can be a single word or more if it is compound one like "get up") returns an object with the source language and a dictionary object:
~~~PowerShell
$response = Invoke-GoogleTranslate -ReturnType Dictionary -InputObject "Ciervo" -SourceLanguage Spanish -TargetLanguage English

$response.SourceLanguage
# es

$response.Dictionary
# WordClass Terms                        Entries
# --------- -----                        -------
# noun      {deer, stag, hart, red deer} {@{Word=deer; ReverseTranslations=System.Object[]; Score=0,4650432}, @{Word=stag; ReverseTranslations=System.Object[]; Score=0,08737902}, @{Word=hart; ReverseTranslation…

$response.Dictionary[0].WordClass
# noun

$response.Dictionary[0].Terms
# deer
# stag
# hart
# red deer

$response.Dictionary[0].Entries
# Word     ReverseTranslations              Score
# ----     -------------------              -----
# deer     {ciervo, venado, hombre virtual}  0,47
# stag     {ciervo}                          0,09
# hart     {ciervo}                          0,05
# red deer {ciervo}                          0,02
~~~

- **Definition**: given single word (this one does not accept compound words). In here the target language makes no sense:
~~~PowerShell
$response = Invoke-GoogleTranslate -ReturnType Definition -InputObject "Water" -SourceLanguage English

$response.SourceLanguage
# es

$result.Definitions
# WordClass Glossary
# --------- --------
# noun      {a colorless, transparent, odorless liquid that forms the seas, lakes, rivers, and rain and is the basis of the fluids of living organis…
# verb      {pour or sprinkle water over (a plant or area) in order to encourage plant growth., (of the eyes) become full of moisture or tears., dil…
~~~

- **Synonym**: given a single word (not compound) it retursn an objet with synonyms for every word. In here the target language is not required, but you can use it to get also the translation:

~~~PowerShell
$response = Invoke-GoogleTranslate -ReturnType Synonym -InputObject "Water" -SourceLanguage English -TargetLanguage Spanish

$response.SourceLanguage
# en

$response.Translation
# Agua

$response.SynonymGroupsPerWordClass
# WordClass Groups
# --------- ------
# noun      {@{Register=System.Object[]; Synonyms=System.Object[]}, @{Register=; Synonyms=System.Object[]}, @{Register=System.Object[]; Synonyms=System.Object[]}, @{Register=; Synonyms=System.Object[]}}
# verb      {@{Register=System.Object[]; Synonyms=System.Object[]}, @{Register=; Synonyms=System.Object[]}, @{Register=; Synonyms=System.Object[]}, @{Register=; Synonyms=System.Object[]}…}

 $response.SynonymGroupsPerWordClass[0].Groups
# Register    Synonyms
# --------    --------
# {rare}      {Adam's ale}
#             {aqua}
# {technical} {H2O}
#             {sea, ocean, lake, loch…}
~~~

- **Example**: given a single word (not compound) returns an object with the source language, the translation and a list of examples:
~~~PowerShell
$response = Invoke-GoogleTranslate -ReturnType Example -InputObject "Water" -SourceLanguage English  -TargetLanguage Spanish

$response.SourceLanguage
# en

$response.Translation
# Agua

$response.Examples
# the smell of frying bacon made Hilary's mouth <b>water</b>
# <b>water</b> pipes
# a <b>water</b> plant
# they stopped to <b>water</b> the horses and to refresh themselves
# she ducked under the <b>water</b>
# ammonia <b>water</b>
# I went out to <b>water</b> the geraniums
# drinking alcohol will make you need to pass <b>water</b> more often
# each bedroom has a washbasin with hot and cold <b>water</b>
# a <b>water</b> sign
~~~

## Extra

The information I used to create the module I got it from [here](https://wiki.freepascal.org/Using_Google_Translate).
Since it's not a full guide about how it works it's possible that there are features I have not implemented or some missing data when parsing the response.

Since it's a free API don't expect high speed responses or even to be allowed to use parellelism.
In a script about multiples sentences from one language to many I've got a speed of 6-8 translations per second.
