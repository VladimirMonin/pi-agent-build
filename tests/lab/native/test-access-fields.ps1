[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$FixtureRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $repo 'scripts/common.ps1')
$parent=Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
$out=Join-Path $parent ('managed-access-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($out)|Out-Null
$map=Get-LabChildEnvironment -LabRoot $out -NpmPrefix (Join-Path $out 'npm-prefix')
foreach($dir in @('temp','home','appdata','localappdata')){[IO.Directory]::CreateDirectory((Join-Path $out $dir))|Out-Null}
Invoke-WithChildEnvironment -Sanitize -Environment $map -ScriptBlock {
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'NativeBoundary.cs'))
$stub=@'
    public static uint TestRid=100,TestAttributes=7,TestPolicy=1,TestFlags=0,TestSourceLength=16,TestAccessLength=1024,TestBufferBytes=1024;
    public static long TestAuth=123,TestPrivilege=23,TestHashValue=42,TestSourceTail=1000;
    public static bool TestOpaque=false,TestBadHashPointer=false,TestBadSidRevision=false,TestBadPrivilegeCount=false,TestFreeFailure=false,TestCloseFailure=false;
    public static long LastSidHashAddress;
    public static List<IntPtr> TestHeap=new List<IntPtr>();
    public static int AccessSize(){return Marshal.SizeOf(typeof(TOKEN_ACCESS_INFORMATION));}
    public static void FreeFixtures(){foreach(IntPtr p in TestHeap)Marshal.FreeHGlobal(p);TestHeap.Clear();}
    static IntPtr TestBase;static int TestOffset;
    static IntPtr Allocate(int bytes){int offset=(TestOffset+7)&~7;TestOffset=offset+bytes;if(TestOffset>TestBufferBytes)throw new InvalidOperationException("Stub inline capacity");IntPtr p=IntPtr.Add(TestBase,offset);for(int i=0;i<bytes;i++)Marshal.WriteByte(p,i,0);return p;}
    static IntPtr Sid(uint rid){IntPtr p=Allocate(12);Marshal.WriteByte(p,0,TestBadSidRevision?(byte)0:(byte)1);Marshal.WriteByte(p,1,1);Marshal.WriteInt32(p,8,unchecked((int)rid));return p;}
    static IntPtr Hash(uint rid){
        IntPtr hash=Allocate(272),array=Allocate(16);Marshal.WriteInt32(hash,1);Marshal.WriteIntPtr(hash,8,array);
        Marshal.WriteIntPtr(array,Sid(rid));Marshal.WriteInt32(array,8,unchecked((int)TestAttributes));Marshal.WriteIntPtr(hash,16,new IntPtr(TestHashValue));return hash;
    }
    static bool GetTokenInformation(IntPtr token,int cls,IntPtr p,uint size,out uint needed){
        needed=cls==7?TestSourceLength:(cls==21?1:(cls==8||cls==23||cls==24?4:TestBufferBytes));
        if(p==IntPtr.Zero){TestLastError=122;return false;}
        if(cls==22)needed=TestAccessLength;
        TestLastError=0;
        if(cls==21){Marshal.WriteByte(p,1);return true;}
        if(cls==8||cls==23||cls==24){Marshal.WriteInt32(p,1);return true;}
        if(cls==7){
            if(size<16)throw new InvalidOperationException("Stub source capacity");
            Marshal.WriteInt64(p,0,0x4142434445464748L);Marshal.WriteInt64(p,8,TestSourceTail);return true;
        }
        if(cls!=22||size<TestBufferBytes)throw new InvalidOperationException("Unrelated class or stub capacity");
        TestBase=p;TestOffset=88;
        IntPtr privileges=Allocate(16);Marshal.WriteInt32(privileges,TestBadPrivilegeCount?65536:1);Marshal.WriteInt64(privileges,4,TestPrivilege);Marshal.WriteInt32(privileges,12,3);
        TOKEN_ACCESS_INFORMATION x=new TOKEN_ACCESS_INFORMATION{SidHash=Hash(TestRid),RestrictedSidHash=Hash(1001),Privileges=privileges,AuthenticationId=TestAuth,TokenType=1,ImpersonationLevel=2,MandatoryPolicy=TestPolicy,Flags=TestFlags,AppContainerNumber=0,PackageSid=IntPtr.Zero,CapabilitiesHash=IntPtr.Zero,TrustLevelSid=IntPtr.Zero,SecurityAttributes=TestOpaque?new IntPtr(1):IntPtr.Zero};
        LastSidHashAddress=x.SidHash.ToInt64();if(TestBadHashPointer)x.SidHash=new IntPtr(1);Marshal.StructureToPtr(x,p,false);return true;
    }
    public static int TestLastError;
    static bool IsTokenRestricted(IntPtr token){return true;}
    static bool ConvertSidToStringSid(IntPtr sid,out IntPtr text){text=Marshal.StringToHGlobalUni("S-1-5-"+unchecked((uint)Marshal.ReadInt32(sid,8)));return true;}
    static IntPtr LocalFree(IntPtr p){if(TestFreeFailure){TestHeap.Add(p);TestLastError=5;return p;}Marshal.FreeHGlobal(p);return IntPtr.Zero;}
    static bool CloseHandle(IntPtr p){TestLastError=TestCloseFailure?6:0;return !TestCloseFailure;}
    public static void Reset(){TestRid=100;TestAttributes=7;TestPolicy=1;TestFlags=0;TestSourceLength=16;TestAccessLength=1024;TestBufferBytes=1024;TestAuth=123;TestPrivilege=23;TestHashValue=42;TestSourceTail=1000;TestOpaque=false;TestBadHashPointer=false;TestBadSidRevision=false;TestBadPrivilegeCount=false;TestFreeFailure=false;TestCloseFailure=false;}
'@
$source=$source.Replace('public static class NativeBoundary {',("public static class AccessFieldsContract {`n"+$stub))
$source=[regex]::Replace($source,'\[DllImport\([^\r\n]*\)\]\s*(static extern [^;\r\n]+);',{
    param($m)
    $decl=$m.Groups[1].Value.Replace('static extern ','static ')
    $name=[regex]::Match($decl,'\s(\w+)\(').Groups[1].Value
    if($name -in @('GetTokenInformation','IsTokenRestricted','ConvertSidToStringSid','LocalFree','CloseHandle')){return ''}
    return $decl+' {throw new InvalidOperationException("Native API disabled in access-fields test: '+$name+'");}'
})
$loop=[regex]::Match($source,'foreach\(TokenInfo infoClass in new\[\]\{[^}]+\}\)').Value
if(([regex]::Matches($source,[regex]::Escape($loop))).Count-ne 1){throw 'Unique consumer loop required'}
$source=$source.Replace($loop,'foreach(TokenInfo infoClass in new[]{TokenInfo.Source,TokenInfo.Type,TokenInfo.HasRestrictions,TokenInfo.AccessInformation,TokenInfo.VirtualizationAllowed,TokenInfo.VirtualizationEnabled})').Replace('Marshal.GetLastWin32Error()','TestLastError')
if($source.Contains('[DllImport(')){throw 'Native import remains'}
[IO.File]::WriteAllText((Join-Path $out 'AccessFieldsContract.cs'),$source)
Add-Type -TypeDefinition $source
if([IntPtr]::Size-ne 8 -or [AccessFieldsContract]::AccessSize()-ne 88){throw 'Supported x64 access-information layout required'}
$type=[AccessFieldsContract];$method=$type.GetMethod('UnchangedTokenFields',[Reflection.BindingFlags]'Static,NonPublic')
$receiptType=$type.GetNestedType('TokenDaclCorrection');$cases=New-Object 'Collections.Generic.List[object]'
function Case([string]$Name,[hashtable]$Changes,[bool]$Success){
    [AccessFieldsContract]::Reset()
    foreach($key in $Changes.Keys){$type.GetField($key).SetValue($null,$Changes[$key])}
    $r=[Activator]::CreateInstance($receiptType);$fields=$null;$actual='success'
    try{$fields=$method.Invoke($null,@($r,[IntPtr]::Zero,'managed-access'))}
    catch{$e=$_.Exception;while($e.InnerException){$e=$e.InnerException};$actual=$e.GetType().Name}
    if(($actual-eq 'success')-ne $Success){throw "Case failed $Name ($actual)"}
    $cases.Add([pscustomobject]@{name=$Name;result='PASS';actual=$actual;sidHashAddress=[AccessFieldsContract]::LastSidHashAddress})
    return $fields
}
try{
    $a=Case 'complete access information identity' @{} $true;$address=[AccessFieldsContract]::LastSidHashAddress
    $b=Case 'relocated nested buffers same semantic identity' @{TestBufferBytes=[uint32]2048;TestAccessLength=[uint32]2048} $true
    if($a['Class22']-ne $b['Class22']-or $address-eq [AccessFieldsContract]::LastSidHashAddress){throw 'Addresses used as identities'}
    foreach($change in @(@{TestRid=[uint32]101},@{TestAttributes=[uint32]8},@{TestPolicy=[uint32]2},@{TestAuth=[long]124},@{TestPrivilege=[long]24},@{TestHashValue=[long]43})){
        $field=($change.Keys|Select-Object -First 1);$c=Case "security field change $field detected" $change $true
        if($a['Class22']-eq $c['Class22']){throw 'Changed access field undetected'}
    }
    $c=Case 'TOKEN_SOURCE tail LUID change detected' @{TestSourceTail=[long]1001} $true
    if($a['Class7']-eq $c['Class7']){throw 'Only first source DWORD compared'}
    $flags=Case 'opaque scalar flags accepted and change detected' @{TestFlags=[uint32]1} $true
    if($a['Class22']-eq $flags['Class22']){throw 'Scalar Flags change undetected'}
    $sameFlags=Case 'same opaque scalar flags preserve semantic identity' @{TestFlags=[uint32]1} $true
    if($flags['Class22']-ne $sameFlags['Class22']){throw 'Same scalar Flags identity changed'}
    $null=Case 'opaque reserved security attributes refused' @{TestOpaque=$true} $false
    $null=Case 'nonzero flags never bypass unknown security attributes refusal' @{TestFlags=[uint32]1;TestOpaque=$true} $false
    $null=Case 'truncated access-information buffer refused' @{TestAccessLength=[uint32]87} $false
    $null=Case 'invalid TOKEN_SOURCE length refused' @{TestSourceLength=[uint32]17} $false
    $null=Case 'out-of-buffer hash pointer refused before dereference' @{TestBadHashPointer=$true} $false
    $null=Case 'unknown SID revision refused' @{TestBadSidRevision=$true} $false
    $null=Case 'privilege count overflow refused' @{TestBadPrivilegeCount=$true} $false
    $null=Case 'genuine LocalFree5 propagated' @{TestFreeFailure=$true} $false
    [AccessFieldsContract]::Reset()
    $close=$type.GetMethod('CloseOwned',[Reflection.BindingFlags]'Static,NonPublic')
    foreach($fail in @($false,$true)){
        [AccessFieldsContract]::TestCloseFailure=$fail;$r=[Activator]::CreateInstance($type.GetNestedType('Receipt'))
        $close.Invoke($null,@($r,[IntPtr]1,'managed-owned-handle'))|Out-Null
        if($r.CleanupResults.Count-ne 1-or $r.CleanupResults[0].Success-eq $fail-or ($fail-and ($r.Status-ne 'FAILED'-or $r.CleanupResults[0].Win32Error-ne 6))){throw 'Owned CloseHandle failure silently accepted'}
        $cases.Add([pscustomobject]@{name="owned CloseHandle failure=$fail recorded";result='PASS'})
    }
    $enumType=$type.GetNestedType('TokenInfo');foreach($pair in @(@('Source',7),@('Type',8),@('LinkedToken',19),@('HasRestrictions',21),@('AccessInformation',22),@('VirtualizationEnabled',24))){if([int][Enum]::Parse($enumType,$pair[0])-ne $pair[1]){throw 'Official Win32 enum mismatch'}}
    foreach($key in @('Class8','Class21','Class23','Class24')){if($a[$key]-ne '00000001'){throw 'Documented DWORD interpreted as struct/handle'}}
    $cases.Add([pscustomobject]@{name='official enum and scalar DWORD classes enforced';result='PASS'})
    $validate=$type.GetMethod('ValidateTokenBuffer',[Reflection.BindingFlags]'Static,NonPublic');$bp=[Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    try{foreach($test in @(@(1,1,$false),@(4,1,$false),@(2,1,$true),@(1,2,$true),@(4,2,$true))){[Runtime.InteropServices.Marshal]::WriteInt32($bp,$test[1]);$rejected=$false;try{$validate.Invoke($null,@($bp,[uint32]$test[0],21))|Out-Null}catch{$rejected=$true};if($rejected-ne $test[2]){throw 'TokenHasRestrictions bool ABI/value contract failed'};$cases.Add([pscustomobject]@{name="HasRestrictions boolean bytes=$($test[0]) value=$($test[1])";result='PASS'})}}finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($bp)}
    $access=[uint32]$type.GetField('CallerTokenAccess',[Reflection.BindingFlags]'Static,NonPublic').GetRawConstantValue()
    if($access-ne 0x9b -or ($access-band 0x10)-eq 0){throw 'TokenSource access missing'}
    $cases.Add([pscustomobject]@{name='caller/new-token handle QUERY_SOURCE access explicit';result='PASS'})
    $aclMethod=$type.GetMethod('RequireExactAclReadback',[Reflection.BindingFlags]'Static,NonPublic')
    [byte[]]$expectedAcl=@(2,0,16,0,0,0,0,0,11,12,13,14,15,16,17,18)
    foreach($kind in @('exact','reserved-header-drift','padding-drift')){
        $r=[Activator]::CreateInstance($receiptType);$r.After=[Activator]::CreateInstance($type.GetNestedType('TokenDacl'))
        [byte[]]$actualAcl=$expectedAcl.Clone()
        if($kind-eq 'reserved-header-drift'){$actualAcl[6]=1};if($kind-eq 'padding-drift'){$actualAcl[15]=19}
        $r.After.RawAclBase64=[Convert]::ToBase64String($actualAcl);$rejected=$false
        try{$aclMethod.Invoke($null,@($r,$expectedAcl))|Out-Null}catch{$rejected=$true}
        if($rejected-ne ($kind-ne 'exact')-or $r.ExactAppendedAclReadback-ne ($kind-eq 'exact')){throw 'Full ACL preservation gate missing'}
        $cases.Add([pscustomobject]@{name="exact ACL readback $kind";result='PASS'})
    }
    [ordered]@{status='MANAGED_ACCESS_FIELDS_PASS_ONLY';caseCount=$cases.Count;cases=$cases;nativeTokenQueries=0;nativeActorLaunches=0;scope='Official enum Source7/Type8/HasRestrictions21/Access22/Virtualization23,24 with managed buffers/stubs; layout88/x64. Pointer relocation, member mutations and reserved/length refusals. Not Windows API validation.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'managed-result.json') -Encoding UTF8
    Write-Output "MANAGED_ACCESS_FIELDS_PASS_ONLY $($cases.Count) cases; native queries/actors0"
}finally{[AccessFieldsContract]::FreeFixtures()}
}
