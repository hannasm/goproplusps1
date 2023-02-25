function GoProPlus-Constants {
 $result = @{
  'appClientId' = '71611e67ea968cfacf45e2b6936c81156fcf5dbe553a2bf2d342da1562d05f46';
  'appClientSecret' = '3863c9b438c07b82f39ab3eeeef9c24fefa50c6856253e3f1d37e0e3b1ead68d';
  'appClientAuthUrl' = 'https://api.gopro.com/v1/oauth2/token';
  'headers' = @{
    'Accept' = 'application/vnd.gopro.jk.media+json; version=2.0.0';
    'Content-Type' = 'application/json';
  };
 };
 return $result;
}

function GoProPlus-LoadSettings {
  param ($filename);
  if (!(test-path $filename)) {
    throw ('unable to load go pro plus settings at ' + (join-path (pwd).Path $filename));
  }
  
  $settings = get-content $filename | convertfrom-json;

  return $settings;
}

function GoProPlus-Authenticate {
  param ($username, $password);

  $constants = GoProPlus-Constants;
  $appAuthPayload = @{ 
    'grant_type' = 'password'; 
    'client_id' = $constants.appClientId; 
    'client_secret' = $constants.appClientSecret; 
    'scope' = 'root root:channels public me upload media_library_beta live'; 
    'username' = $username; 
    'password' = $password; 
  }
  $appAuthToken = Invoke-RestMethod -Method Post -Uri $constants.appClientAuthUrl -Body $appAuthPayload
  return $appAuthToken;
}

function GoProPlus-RefreshToken {
  param ($appAuthToken);

  $constants = GoProPlus-Constants;

  $refreshPayload = @{
    'grant_type' = 'refresh_token';
    'client_id' = $constants.appClientId;
    'client_secret' = $constants.appClientSecret;
    'refresh_token' = $appAuthToken.refresh_token;
  };

  $appAuthToken2 = Invoke-RestMethod -Method Post -Uri $constants.appClientAuthUrl -Body 
  return $appAuthToken2;
}

function GoProPlus-ListPage {
  param ([Parameter(Mandatory=$true)]$appAuthToken, $pageNo = 1, $pageSize = 20);

   if (!$pageNo) {
     $pageNo = 1;
   }

  $constants = GoProPlus-Constants;

  $listUrl = 'https://api.gopro.com/media/search?fields=captured_at,created_at,file_size,id,moments_count,ready_to_view,source_duration,type,token,width,height,camera_model&order_by=created_at&per_page=' + $pageSize + '&page=' + $pageNo;

  $result = Invoke-RestMethod -Method Get -Uri $listUrl -Headers $constants.headers -Authentication Bearer -Token ($appAuthToken.access_token | ConvertTo-SecureString -AsPlainText);

  return $result;
}

function GoProPlus-ListFilesPage {
  param ([Parameter(Mandatory=$true)]$appAuthToken, $pageNo = 0, $pageSize = 20);

  $res = GoProPlus-ListPage $appAuthToken $pageNo $pageSize;

  $res2 = $res._embedded.media;

  return $res2;
}

function GoProPlus-ListAllFiles {
  param ([Parameter(Mandatory=$true)]$appAuthToken);

  $results = @();
  $pageNo = $null;
  do {
    $res = GoProPlus-ListPage -appAuthToken $appAuthToken -pageNo $pageNo;
    $pageNo = $res._pages.current_page + 1;
    $results += $res._embedded.media;
  } while ($pageNo -le $res._pages.total_pages);

  return $results;
}

function GoProPlus-Moments2 {
  param ([Parameter(Mandatory=$true)]$appAuthToken, [Parameter(Mandatory=$true)]$target);

  $constants = GoProPlus-Constants;
  $downloadUri = 'https://api.gopro.com/media/' + $target.id + '/moments?fields=time';

  $result = Invoke-RestMethod -Method Get -Uri $downloadUri -Headers $constants.headers -Authentication Bearer -Token ($appAuthToken.access_token | ConvertTo-SecureString -AsPlainText);

  return $result;
}
function GoProPlus-Download2 {
  param ([Parameter(Mandatory=$true)]$appAuthToken, [Parameter(Mandatory=$true)]$target);

  $constants = GoProPlus-Constants;
  $downloadUri = 'https://api.gopro.com/media/' + $target.id + '/download';

  $result = Invoke-RestMethod -Method Get -Uri $downloadUri -Headers $constants.headers -Authentication Bearer -Token ($appAuthToken.access_token | ConvertTo-SecureString -AsPlainText);

  return $result;
}
function GoProPlus-GetExtensionFromDownload2 {
  param ([Parameter(Mandatory=$true)]$download2);

  $uri = [Uri]::new($download2._embedded.files[0].url);

  return [System.IO.Path]::GetExtension($uri.AbsolutePath);
}

function GoProPlus-Download {
  param ([Parameter(Mandatory=$true)]$appAuthToken, [Parameter(Mandatory=$true, ParameterSetName='asFile')]$target, [Parameter(Mandatory=$true, ParameterSetName='fromDownload2')]$download2 = $null, [Parameter(Mandatory=$true)]$outputFileName);

  if ($download2) {
    $result = $download2;
  } else {
    $result = GoProPlus-Download2 $appAuthToken $target;
    $extension = GoProPlus-GetExtensionFromDownload2 $result;
    $outputFileName += $extension;
  }

  $result2 = Invoke-WebRequest -Method Get -Uri $result._embedded.files[0].url -OutFile $outputFileName;

  return $outputFileName;
}
