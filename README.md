# GoProPlusPs1
This repository contains some basic powershell commands for interacting with a GoPro Plus cloud storage account via Powershell. It currently provides basic read-only functionality including:

  * authentication
  * listing stored content * retrieving stored content
  * retrieving associated moment metadata

This library will ideally be extended in the future to support various other functionality provided by the (undocumented) GoProPlus api.

## Setup

Download the goproplus.ps1 script to your file system and dot source it.

```ps1
. ./gopro_plus.ps1
```

## Configuration
For convenience, and at your discretion, you can choose to create a configuration file containing your credentials and ideally stored in a place that is secure from disclosures. This configuration can then be loaded and used to access goproplus in a more secure way.

```json
// goprosettings.json
{
  'username': 'my_gopro_username',
  'password': 'my_gopro_password'
}
```

with the file created you can load this file into your powershell session

```ps1
$gppConfig = GoProPlus-LoadSettings 'goprosettings.json';
```

## Authentication
Before accessing goproplus you must first generate an access token. You can use the configuration file option above or enter credentials some other way.

```ps1
$gppToken = GoProPlus-Authenticate $gppConfig.username $gppConfig.password;
```

Once authenticated the access token will eventually expire. If long-term retention of this access token is desired you may also be interested in performing a token refresh as well:

```ps1
$gppToken = GoProPlus-RefreshToken $gppToken;
``` 

## Enumerate Content

To read all files and their core metadata in one go use ListAllFiles. This method does a few extra steps to page the data from the cloud and remove some of the technical parts of the data. This method returns an array containing one object per file with all the data returned from the cloud api.

```ps1
$allFiles = GoProPlus-ListAllFiles $gppToken;
```

You can also page the data yourself and access the raw response data from goproplus cloud directly if you prefer.

```ps1
$response = GoProPlus-ListPage $gppToken -pageNo 1 -pageSize 20;
```

*TODO* Implement More Robust Querying - The current method lists data sorted on create date but there are other sorting and filtering options supported by the cloud api
*TODO* Implement more robust Data Access - The current method returns a robust set of fields from the cloud api but the cloud api supports controlling which fields are returned and also may offer some additional data not currently being retrieved

## Download Content

GoProPlus downloads invovle two steps, first a url must be generated and then second the generatd url must be accessed. The powershell API provides access to each part of the process but also provides a simpler form of access.

To generate the download url invoke the following:

```ps1
$fileUrl = GoProPlus-Download2 $gppToken $allFiles[0];
```

The file extension to use for the downloaded content is not known until these download urls are generated so as an intermediate step it is also necesarry to calculate the file extension at this point. 


```ps1
$fileExtension = GoProPlus-GetExtensionFromDownload2 $fileUrl;
$outputFilename = 'goProContent_' + [DateTime]::Now.ToString('o') + $fileExtension;
```

*NOTE* The file extension generated here contains the leading '.'

*NOTE* GoProPlus supports users uploading content from other cameras, and some content is generated from the cloud. As a result of this some data that may be return for many files stored in go pro plus will not be available for these special case files. As stated, the above process to generate $outputFilename has been experimentally determined to provide a valid filename in all cases, although clearly for a simple image / video uploaded from your camera may be able to produce a better filename. If you are worried about having good filenames you will need to experiment with the data provided from the cloud for your specific files and determine the best way to approach file naming using a process similar to the above but which meets your needs.

Finally the data can be downloaded and written to disk

```ps1
$outputFilename = GoProPlus-Download -appAuthToken $gppToken -fromDownload2 $fileUrl -outputFilename $outputFilename
```

In cases where the filename is not of interest a more straightforward option is also available:

```ps1
$outputFilename = GoProPlus-Download -appAuthToken $gppTOken -target $allFiles[0] -outputFilename ([Guid]::NewGuid().ToString('N'));
```

This invocation will calcualte and then append the file extension automatically to the provided 'outputFilename' argument and return that new name. The file will be written to disk in the current working directory or whichever path is provided in the outputFilename argument.

## Moments
Raw moment data can be retrieved from the cloud using the following command:

```ps1
$moments = GoProPlus-Moments2 -appAuthToken $gppToken -target $allFiles[0];
```

This returns the raw json object returned by the cloud without manipulation. It will remain an exercise for the user to wrangle data from this raw output but in the future a new GoProPlus-Moments api may be created to support a more intuitive use case. 

*TODO* It looks like this API may require paging for larger videos with a large number of moments captured. We need to implement that.

## Acknowledgements

Most of the hardwork reverse engineering the gopro plus cloud api was done by [https://github.com/dustin/gopro](https://github.com/dustin/gopro). A big thanks to dustin for making the haskell source code availble which i have simply ported / reimplemented in powershell.
