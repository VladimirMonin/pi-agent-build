using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Diagnostics;
using System.ComponentModel;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;

// Private lab only. No package loading, elevation, network, or global ACL mutation.
public static class NativeBoundary {
    public enum TokenInfo { User=1, Groups=2, Privileges=3, Owner=4, PrimaryGroup=5, DefaultDacl=6, Source=7, Type=8, Statistics=10, RestrictedSids=11, SessionId=12, ElevationType=18, LinkedToken=19, Elevation=20, HasRestrictions=21, AccessInformation=22, VirtualizationAllowed=23, VirtualizationEnabled=24, IntegrityLevel=25, UIAccess=26, MandatoryPolicy=27 }
    const uint CallerTokenAccess=0x9b; // QUERY_SOURCE|QUERY|DUPLICATE|ASSIGN_PRIMARY|ADJUST_DEFAULT, no privilege/content mutation.
    [StructLayout(LayoutKind.Sequential)] struct SID_AND_ATTRIBUTES { public IntPtr Sid; public uint Attributes; }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_STATISTICS {
        public long TokenId, AuthenticationId, ExpirationTime;
        public uint TokenType, ImpersonationLevel, DynamicCharged, DynamicAvailable, GroupCount, PrivilegeCount;
        public long ModifiedId;
    }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_ACCESS_INFORMATION {
        public IntPtr SidHash, RestrictedSidHash, Privileges;
        public long AuthenticationId;
        public uint TokenType, ImpersonationLevel, MandatoryPolicy, Flags, AppContainerNumber;
        public IntPtr PackageSid, CapabilitiesHash, TrustLevelSid, SecurityAttributes;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct STARTUPINFO {
        public uint cb; public string reserved, desktop, title; public uint x,y,xsize,ysize,xchars,ychars,fill,flags;
        public ushort show, reserved2; public IntPtr reservedPtr, input, output, error;
    }
    [StructLayout(LayoutKind.Sequential)] struct STARTUPINFOEX { public STARTUPINFO startup; public IntPtr attributes; }
    [StructLayout(LayoutKind.Sequential)] struct SECURITY_ATTRIBUTES { public uint length; public IntPtr descriptor; [MarshalAs(UnmanagedType.Bool)] public bool inherit; }
    [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateFile(string path,uint access,uint share,ref SECURITY_ATTRIBUTES security,uint disposition,uint flags,IntPtr template);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetHandleInformation(IntPtr h,out uint flags);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetHandleInformation(IntPtr h,uint mask,uint flags);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint GetFileType(IntPtr h);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr list,int count,uint flags,ref IntPtr size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr list,uint flags,IntPtr attribute,IntPtr value,IntPtr size,IntPtr previous,IntPtr returned);
    [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr list);
    [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr process, thread; public uint pid, tid; }
    [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMIT {
        public long processTime, jobTime; public uint flags; public UIntPtr minWs,maxWs; public uint activeLimit; public UIntPtr affinity; public uint priority,scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong readOps,writeOps,otherOps,readBytes,writeBytes,otherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct EXTENDED_LIMIT { public BASIC_LIMIT basic; public IO_COUNTERS io; public UIntPtr processMemory,jobMemory,peakProcess,peakJob; }
    [StructLayout(LayoutKind.Sequential)] struct COMPLETION_ASSOC { public IntPtr key,port; }
    [StructLayout(LayoutKind.Sequential)] struct BASIC_ACCOUNTING { public long user,kernel,periodUser,periodKernel; public uint faults,total,active,terminated; }
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,uint pid);
    [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool QueryFullProcessImageName(IntPtr h,uint flags,StringBuilder path,ref uint size);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,uint access,out IntPtr t);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool CreateRestrictedToken(IntPtr t,uint flags,uint disableCount,IntPtr disable,uint deleteCount,IntPtr delete,uint restrictCount,ref SID_AND_ATTRIBUTES restrict,out IntPtr result);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr t,int cls,IntPtr data,uint size,out uint needed);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool SetTokenInformation(IntPtr t,int cls,ref SID_AND_ATTRIBUTES data,uint size);
    [DllImport("advapi32.dll",SetLastError=true,EntryPoint="SetTokenInformation")] static extern bool SetTokenDefaultDacl(IntPtr t,int cls,IntPtr data,uint size);
    [DllImport("advapi32.dll")] static extern bool IsTokenRestricted(IntPtr t);
    [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool ConvertStringSidToSid(string text,out IntPtr sid);
    [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool ConvertSidToStringSid(IntPtr sid,out IntPtr text);
    [DllImport("advapi32.dll")] static extern uint GetLengthSid(IntPtr sid);
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr LocalFree(IntPtr p);
    [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(string sddl,uint revision,out IntPtr descriptor,out uint size);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorSacl(IntPtr sd,out bool present,out IntPtr sacl,out bool def);
    [DllImport("advapi32.dll",CharSet=CharSet.Unicode)] static extern uint SetNamedSecurityInfo(string name,int type,uint info,IntPtr owner,IntPtr group,IntPtr dacl,IntPtr sacl);
    [DllImport("advapi32.dll",CharSet=CharSet.Unicode)] static extern uint GetNamedSecurityInfo(string name,int type,uint info,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr sd);
    [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool ConvertSecurityDescriptorToStringSecurityDescriptor(IntPtr sd,uint revision,uint info,out IntPtr text,out uint size);
    [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool CreateProcessAsUser(IntPtr token,string app,StringBuilder cmd,IntPtr psa,IntPtr tsa,bool inherit,uint flags,IntPtr env,string cwd,ref STARTUPINFOEX startup,out PROCESS_INFORMATION process);
    [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr sa,string name);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int cls,IntPtr data,uint len);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr j,int cls,IntPtr data,uint len,IntPtr returned);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr j,IntPtr p);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool IsProcessInJob(IntPtr p,IntPtr j,out bool result);
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateIoCompletionPort(IntPtr file,IntPtr port,IntPtr key,uint threads);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetQueuedCompletionStatus(IntPtr port,out uint msg,out IntPtr key,out IntPtr value,uint ms);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr p,out uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr j,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr p,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr h,uint ms);

    public class Identity {
        public uint Pid; public string Image, UserSid, IntegritySid; public bool Restricted, InJob;
        public List<string> RestrictingSids = new List<string>();
        public List<string> EnabledPrivilegeLuids = new List<string>();
        public uint ExitCode = 259;
        public string ExitCodeHex;
    }
    public class Event { public long ElapsedMs; public uint Message; public long PidOrValue; public string Name; }
    public class IoHandle {
        public string Role, Path, Access; public long Handle; public uint FileType, FlagsBeforeLaunch, FlagsAfterLaunch;
        public bool Closed;
    }
    public class WindowObjects {
        public uint HelperPid;
        public string StationName, DesktopName, OriginalName, OriginalBeforeSddl, OriginalAfterSddl, StationSddl, DesktopSddl, DesktopBinding;
        public long OriginalHandle;
        public bool NonInteractive, RestoredBeforeLaunch, RestoredFinally, OriginalUnchanged, DesktopClosed, StationClosed;
        public List<string> Operations=new List<string>();
    }
    public class TokenDaclAce { public int Index; public string Type, Flags, Sid, MaskHex, RawBase64; }
    public class TokenDacl { public string RawAclBase64, Sddl; public List<TokenDaclAce> Aces=new List<TokenDaclAce>(); }
    public class DaclApi { public string Api; public bool Success; public int Win32Error; public uint Capacity, ReturnedBytes; }
    public class TokenDaclCorrection {
        public TokenDacl Before, After;
        public Dictionary<string,string> IdentityBefore, IdentityAfter;
        public bool OriginalAcesUnchanged, OnlyIntendedAceAdded, OtherTokenFieldsUnchanged, ExactAppendedAclReadback, AllocationsFreed;
        public string KernelSdCoverage="NOT_COLLECTED: optional suspended root process/thread security metadata omitted; no access rights widened";
        public List<DaclApi> ApiResults=new List<DaclApi>();
    }
    public class Receipt {
        public TokenDaclCorrection DefaultDacl=new TokenDaclCorrection();
        public WindowObjects Windows=new WindowObjects();
        public string Status="BLOCKED_RUNNER_UNAVAILABLE", Error, RestrictingSid, RuntimeSddl, CanarySddl;
        public int ErrorWin32Code;
        public string ConsoleMode;
        public uint CreationFlags, StartupFlags;
        public long StandardInput, StandardOutput, StandardError;
        public bool HandleListApplied;
        public List<IoHandle> HandleAllowlist=new List<IoHandle>();
        public List<DaclApi> CleanupResults=new List<DaclApi>();
        public Identity PreparedToken; public uint RootPid, JobLimitFlags, ActiveAtClose;
        public bool AssignedBeforeResume, InheritHandles, JobEmpty, ForcedCleanup, LowIntegrity;
        public List<Identity> Processes=new List<Identity>(); public List<Event> Events=new List<Event>();
    }
    static void Check(bool ok,string api) { if(!ok) throw new Win32Exception(Marshal.GetLastWin32Error(),api); }
    static void FreeLocal(IntPtr p,string role) {if(LocalFree(p)!=IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"LocalFree "+role);}
    static string SidText(IntPtr sid) { IntPtr text; Check(ConvertSidToStringSid(sid,out text),"ConvertSidToStringSid"); try{return Marshal.PtrToStringUni(text);}finally{FreeLocal(text,"SID text");} }
    static void Range(IntPtr buffer,uint bytes,IntPtr p,long length) {
        ulong b=unchecked((ulong)buffer.ToInt64()),v=unchecked((ulong)p.ToInt64());
        if(p==IntPtr.Zero||length<0||v<b||v-b>bytes||(ulong)length>bytes-(v-b))throw new InvalidOperationException("Token data outside returned buffer");
    }
    static void SidRange(IntPtr buffer,uint bytes,IntPtr sid) {
        Range(buffer,bytes,sid,8);int count=Marshal.ReadByte(sid,1);
        if(Marshal.ReadByte(sid)!=1||count>15)throw new InvalidOperationException("Unsupported SID structure");
        Range(buffer,bytes,sid,8+4L*count);
    }
    static int CountRange(IntPtr buffer,uint bytes,IntPtr p,int start,int step) {
        Range(buffer,bytes,p,4);int count=Marshal.ReadInt32(p);
        if(count<0||count>65535)throw new InvalidOperationException("Invalid token array count");
        Range(buffer,bytes,p,start+(long)step*count);return count;
    }
    static void ValidateTokenBuffer(IntPtr p,uint bytes,int cls) {
        if(cls==(int)TokenInfo.Type||cls==(int)TokenInfo.SessionId||cls==(int)TokenInfo.ElevationType||cls==(int)TokenInfo.Elevation||cls==(int)TokenInfo.VirtualizationAllowed||cls==(int)TokenInfo.VirtualizationEnabled||cls==(int)TokenInfo.UIAccess||cls==(int)TokenInfo.MandatoryPolicy){if(bytes!=4)throw new InvalidOperationException("Invalid token DWORD length");}
        // Actual Windows GetTokenInformation returns BOOLEAN(1) here; Win32 docs describe DWORD(4).
        // Accept only those explicit boolean encodings and values 0/1, never arbitrary lengths.
        else if(cls==(int)TokenInfo.HasRestrictions){
            if(bytes!=1&&bytes!=4)throw new InvalidOperationException("Invalid TokenHasRestrictions boolean length");
            uint value=bytes==1?Marshal.ReadByte(p):unchecked((uint)Marshal.ReadInt32(p));
            if(value>1)throw new InvalidOperationException("Invalid TokenHasRestrictions boolean value");
        }
        else if(cls==(int)TokenInfo.Source){if(bytes!=16)throw new InvalidOperationException("Invalid TOKEN_SOURCE length");}
        else if(cls==1||cls==25){Range(p,bytes,p,Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES)));SidRange(p,bytes,Marshal.ReadIntPtr(p));}
        else if(cls==4||cls==5){Range(p,bytes,p,IntPtr.Size);SidRange(p,bytes,Marshal.ReadIntPtr(p));}
        else if(cls==2||cls==11){int start=IntPtr.Size==8?8:4,step=Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES)),count=CountRange(p,bytes,p,start,step);for(int i=0;i<count;i++)SidRange(p,bytes,Marshal.ReadIntPtr(p,start+i*step));}
        else if(cls==3)CountRange(p,bytes,p,4,12);
        else if(cls==6){Range(p,bytes,p,IntPtr.Size);IntPtr acl=Marshal.ReadIntPtr(p);Range(p,bytes,acl,8);int size=unchecked((ushort)Marshal.ReadInt16(acl,2));if(size<8)throw new InvalidOperationException("Invalid default ACL size");Range(p,bytes,acl,size);}
        else if(cls==(int)TokenInfo.AccessInformation){if(IntPtr.Size!=8)throw new InvalidOperationException("Only x64 access-information layout supported");Range(p,bytes,p,Marshal.SizeOf(typeof(TOKEN_ACCESS_INFORMATION)));}
        else throw new InvalidOperationException("Unsupported token information class");
    }
    static IntPtr Info(IntPtr token,int cls) {
        return DaclInfo(new TokenDaclCorrection(),token,cls,"identity");
    }
    static Identity TokenIdentity(IntPtr token) {
        Identity r=new Identity(); r.Restricted=IsTokenRestricted(token);
        IntPtr p=Info(token,1); try{r.UserSid=SidText(Marshal.ReadIntPtr(p));}finally{Marshal.FreeHGlobal(p);}
        p=Info(token,25); try{r.IntegritySid=SidText(Marshal.ReadIntPtr(p));}finally{Marshal.FreeHGlobal(p);}
        p=Info(token,11); try{
            int n=Marshal.ReadInt32(p), start=IntPtr.Size==8?8:4, step=Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES));
            for(int i=0;i<n;i++) r.RestrictingSids.Add(SidText(Marshal.ReadIntPtr(p,start+i*step)));
        }finally{Marshal.FreeHGlobal(p);}
        p=Info(token,3); try{
            int n=Marshal.ReadInt32(p);
            for(int i=0;i<n;i++) if((Marshal.ReadInt32(p,4+i*12+8)&2)!=0)
                r.EnabledPrivilegeLuids.Add(Marshal.ReadInt64(p,4+i*12).ToString());
        }finally{Marshal.FreeHGlobal(p);}
        return r;
    }
    static void DaclCheck(TokenDaclCorrection r,bool ok,string api) {
        int error=ok?0:Marshal.GetLastWin32Error();
        r.ApiResults.Add(new DaclApi{Api=api,Success=ok,Win32Error=error});
        if(!ok)throw new Win32Exception(error,api);
    }
    static IntPtr DaclInfo(TokenDaclCorrection r,IntPtr token,int cls,string phase) {
        string api="GetTokenInformation NEW token "+phase+" class "+cls;
        // TokenElevation (20) is TOKEN_ELEVATION: exactly one DWORD, not a variable buffer.
        // Query its documented size directly; never accept an API error as successful data.
        uint size=4;
        if(cls!=20) {
            bool ok=GetTokenInformation(token,cls,IntPtr.Zero,0,out size);
            int error=ok?0:Marshal.GetLastWin32Error();
            r.ApiResults.Add(new DaclApi{Api=api+" size",Success=ok,Win32Error=error});
            if(ok||error!=122||size==0)throw new Win32Exception(error,api+" unexpected sizing result");
        }
        IntPtr p=Marshal.AllocHGlobal(checked((int)size));
        try {uint capacity=size;DaclCheck(r,GetTokenInformation(token,cls,p,capacity,out size),api);r.ApiResults.Last().Capacity=capacity;r.ApiResults.Last().ReturnedBytes=size;if(size>capacity||(cls==20&&size!=4))throw new InvalidOperationException("Token query returned invalid length");ValidateTokenBuffer(p,size,cls);return p;}
        catch {Marshal.FreeHGlobal(p);throw;}
    }
    static byte[] DaclBytes(IntPtr acl) {
        if(acl==IntPtr.Zero)throw new InvalidOperationException("Null new-token default DACL refused");
        int size=unchecked((ushort)Marshal.ReadInt16(acl,2));
        if(size<8)throw new InvalidOperationException("Invalid default ACL size");
        byte[] bytes=new byte[size];Marshal.Copy(acl,bytes,0,size);return bytes;
    }
    static TokenDacl ReadDefaultDacl(TokenDaclCorrection r,IntPtr token,string phase) {
        IntPtr p=DaclInfo(r,token,6,phase);
        try {
            byte[] bytes=DaclBytes(Marshal.ReadIntPtr(p));RawAcl acl=new RawAcl(bytes,0);
            var value=new TokenDacl{RawAclBase64=Convert.ToBase64String(bytes),Sddl=new RawSecurityDescriptor(ControlFlags.DiscretionaryAclPresent,null,null,null,acl).GetSddlForm(AccessControlSections.Access)};
            // Slice the OS bytes, not a reserialized ACE: preservation is binary and ordered.
            int offset=8;
            for(int i=0;i<acl.Count;i++) {
                int length=bytes[offset+2]|(bytes[offset+3]<<8);byte[] raw=new byte[length];Buffer.BlockCopy(bytes,offset,raw,0,length);
                KnownAce known=acl[i] as KnownAce;
                value.Aces.Add(new TokenDaclAce{Index=i,Type=acl[i].AceType.ToString(),Flags=acl[i].AceFlags.ToString(),Sid=known==null?null:known.SecurityIdentifier.Value,MaskHex=known==null?null:"0x"+unchecked((uint)known.AccessMask).ToString("X8"),RawBase64=Convert.ToBase64String(raw)});
                offset+=length;
            }
            return value;
        } finally {Marshal.FreeHGlobal(p);}
    }
    static string LinkedTokenIdentity(TokenDaclCorrection r,IntPtr token,string phase) {
        IntPtr p=Marshal.AllocHGlobal(IntPtr.Size),linked=IntPtr.Zero,statistics=IntPtr.Zero;
        try {
            Marshal.WriteIntPtr(p,IntPtr.Zero);
            uint returned;bool ok=GetTokenInformation(token,(int)TokenInfo.LinkedToken,p,(uint)IntPtr.Size,out returned);
            int error=ok?0:Marshal.GetLastWin32Error();
            // Capture ownership before validation so a successful malformed result still closes.
            if(ok)linked=Marshal.ReadIntPtr(p);
            r.ApiResults.Add(new DaclApi{Api="GetTokenInformation NEW token "+phase+" TokenLinkedToken class 19",Success=ok,Win32Error=error});
            if(!ok)throw new Win32Exception(error,"TokenLinkedToken query failed");
            if(returned!=(uint)IntPtr.Size||linked==IntPtr.Zero||linked==new IntPtr(-1))throw new InvalidOperationException("Invalid linked-token HANDLE result");
            uint capacity=(uint)Marshal.SizeOf(typeof(TOKEN_STATISTICS));statistics=Marshal.AllocHGlobal(checked((int)capacity));
            DaclCheck(r,GetTokenInformation(linked,10,statistics,capacity,out returned),"GetTokenInformation owned linked token "+phase+" TokenStatistics class 10");
            if(returned!=capacity)throw new InvalidOperationException("Invalid linked-token statistics length");
            TOKEN_STATISTICS value=(TOKEN_STATISTICS)Marshal.PtrToStructure(statistics,typeof(TOKEN_STATISTICS));
            // TokenId identifies the token object; fresh HANDLE numbers are not identities.
            return unchecked((ulong)value.TokenId).ToString("X16")+":"+unchecked((ulong)value.AuthenticationId).ToString("X16")+":"+unchecked((ulong)value.ModifiedId).ToString("X16");
        } finally {
            try {if(linked!=IntPtr.Zero&&linked!=new IntPtr(-1))DaclCheck(r,CloseHandle(linked),"CloseHandle owned linked token "+phase);}
            finally {if(statistics!=IntPtr.Zero)Marshal.FreeHGlobal(statistics);Marshal.FreeHGlobal(p);}
        }
    }
    static string PrivilegeIdentity(IntPtr buffer,uint bytes,IntPtr p) {
        if(p==IntPtr.Zero)return "NULL";
        int count=CountRange(buffer,bytes,p,4,12);
        var values=new List<string>();
        for(int i=0;i<count;i++)values.Add(Marshal.ReadInt64(p,4+i*12).ToString()+":"+unchecked((uint)Marshal.ReadInt32(p,12+i*12)).ToString("X8"));
        return string.Join("|",values.ToArray());
    }
    static string SidHashIdentity(IntPtr buffer,uint bytes,IntPtr p) {
        if(p==IntPtr.Zero)return "NULL";
        int offset=IntPtr.Size==8?8:4;Range(buffer,bytes,p,offset+IntPtr.Size+32*IntPtr.Size);
        int count=Marshal.ReadInt32(p);
        if(count<0||count>65535)throw new InvalidOperationException("Invalid SID hash count");
        IntPtr array=Marshal.ReadIntPtr(p,offset);
        if(count>0&&array==IntPtr.Zero)throw new InvalidOperationException("Null SID attribute array");
        var values=new List<string>();int step=Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES));
        if(count>0)Range(buffer,bytes,array,(long)count*step);
        for(int i=0;i<count;i++){SID_AND_ATTRIBUTES x=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(IntPtr.Add(array,i*step),typeof(SID_AND_ATTRIBUTES));SidRange(buffer,bytes,x.Sid);values.Add(SidText(x.Sid)+":"+x.Attributes.ToString("X8"));}
        // Hash is an inline array of 32 ULONG_PTR index values, not the SidAttr address.
        for(int i=0;i<32;i++)values.Add(unchecked((ulong)Marshal.ReadIntPtr(p,offset+IntPtr.Size+i*IntPtr.Size).ToInt64()).ToString("X16"));
        return count+":"+string.Join("|",values.ToArray());
    }
    static string AccessIdentity(IntPtr p,uint bytes) {
        if(IntPtr.Size!=8||bytes<(uint)Marshal.SizeOf(typeof(TOKEN_ACCESS_INFORMATION)))throw new InvalidOperationException("Unsupported token access information layout");
        TOKEN_ACCESS_INFORMATION x=(TOKEN_ACCESS_INFORMATION)Marshal.PtrToStructure(p,typeof(TOKEN_ACCESS_INFORMATION));
        // Reserved scalar Flags has no documented zero-value requirement. Preserve every bit
        // in the identity below; do not interpret it or change token rights. Unknown pointer
        // structure is different: refuse it before dereferencing or mutating the NEW token.
        if(x.SecurityAttributes!=IntPtr.Zero)throw new InvalidOperationException("Unsupported non-NULL token access SecurityAttributes structure");
        if(x.PackageSid!=IntPtr.Zero)SidRange(p,bytes,x.PackageSid);if(x.TrustLevelSid!=IntPtr.Zero)SidRange(p,bytes,x.TrustLevelSid);
        return string.Join(";",new[]{SidHashIdentity(p,bytes,x.SidHash),SidHashIdentity(p,bytes,x.RestrictedSidHash),PrivilegeIdentity(p,bytes,x.Privileges),unchecked((ulong)x.AuthenticationId).ToString("X16"),x.TokenType.ToString(),x.ImpersonationLevel.ToString(),x.MandatoryPolicy.ToString("X8"),x.Flags.ToString("X8"),x.AppContainerNumber.ToString(),x.PackageSid==IntPtr.Zero?"NULL":SidText(x.PackageSid),SidHashIdentity(p,bytes,x.CapabilitiesHash),x.TrustLevelSid==IntPtr.Zero?"NULL":SidText(x.TrustLevelSid),"SecurityAttributes=NULL"});
    }
    static Dictionary<string,string> UnchangedTokenFields(TokenDaclCorrection r,IntPtr token,string phase) {
        var fields=new Dictionary<string,string>();
        // Pointer-containing token classes are compared semantically, including every attribute.
        foreach(TokenInfo infoClass in new[]{TokenInfo.User,TokenInfo.Groups,TokenInfo.Privileges,TokenInfo.Owner,TokenInfo.PrimaryGroup,TokenInfo.Source,TokenInfo.Type,TokenInfo.RestrictedSids,TokenInfo.SessionId,TokenInfo.ElevationType,TokenInfo.LinkedToken,TokenInfo.Elevation,TokenInfo.HasRestrictions,TokenInfo.AccessInformation,TokenInfo.VirtualizationAllowed,TokenInfo.VirtualizationEnabled,TokenInfo.IntegrityLevel,TokenInfo.UIAccess,TokenInfo.MandatoryPolicy}) {
            int cls=(int)infoClass;
            if(infoClass==TokenInfo.LinkedToken) {
                string elevation=fields["Class18"];
                // Documented TokenElevationTypeDefault (1): the token has no linked token.
                if(elevation=="00000001")fields.Add("Class19","NO_LINKED_TOKEN:TokenElevationTypeDefault");
                else if(elevation=="00000002"||elevation=="00000003")fields.Add("Class19",LinkedTokenIdentity(r,token,phase));
                else throw new InvalidOperationException("Unknown token elevation type");
                continue;
            }
            IntPtr p=DaclInfo(r,token,cls,phase);
            try {
                var values=new List<string>();
                if(cls==1||cls==25) {SID_AND_ATTRIBUTES x=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(p,typeof(SID_AND_ATTRIBUTES));values.Add(SidText(x.Sid)+":"+x.Attributes.ToString("X8"));}
                else if(cls==4||cls==5)values.Add(SidText(Marshal.ReadIntPtr(p)));
                else if(cls==2||cls==11) {
                    int count=Marshal.ReadInt32(p),start=IntPtr.Size==8?8:4,step=Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES));
                    for(int i=0;i<count;i++){SID_AND_ATTRIBUTES x=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(IntPtr.Add(p,start+i*step),typeof(SID_AND_ATTRIBUTES));values.Add(SidText(x.Sid)+":"+x.Attributes.ToString("X8"));}
                } else if(cls==3)values.Add(PrivilegeIdentity(p,r.ApiResults.Last().ReturnedBytes,p));
                else if(infoClass==TokenInfo.Source) {
                    if(r.ApiResults.Last().ReturnedBytes!=16)throw new InvalidOperationException("Invalid TOKEN_SOURCE length");
                    byte[] source=new byte[16];Marshal.Copy(p,source,0,16);values.Add(Convert.ToBase64String(source));
                } else if(infoClass==TokenInfo.HasRestrictions)values.Add((r.ApiResults.Last().ReturnedBytes==1?(uint)Marshal.ReadByte(p):unchecked((uint)Marshal.ReadInt32(p))).ToString("X8"));
                else if(infoClass==TokenInfo.AccessInformation)values.Add(AccessIdentity(p,r.ApiResults.Last().ReturnedBytes));
                else values.Add(unchecked((uint)Marshal.ReadInt32(p)).ToString("X8"));
                fields.Add("Class"+cls,string.Join("|",values.ToArray()));
            } finally {Marshal.FreeHGlobal(p);}
        }
        fields.Add("IsTokenRestricted",IsTokenRestricted(token).ToString());return fields;
    }
    static void RequireExactAclReadback(TokenDaclCorrection r,byte[] expected) {
        r.ExactAppendedAclReadback=r.After!=null&&r.After.RawAclBase64==Convert.ToBase64String(expected);
        if(!r.ExactAppendedAclReadback)throw new InvalidOperationException("Full default ACL readback differs from exact appended bytes");
    }
    // Sole added mutation: the NEW token's creation default, never an existing object's ACL.
    static void CorrectNewTokenDacl(IntPtr token,string sid,TokenDaclCorrection r) {
        IntPtr acl=IntPtr.Zero,info=IntPtr.Zero;
        try {
            r.Before=ReadDefaultDacl(r,token,"before");r.IdentityBefore=UnchangedTokenFields(r,token,"before");
            if(r.Before.Aces.Any(x=>x.Sid==sid))throw new InvalidOperationException("Unique restricting SID already in default DACL");
            SecurityIdentifier unique=new SecurityIdentifier(sid);
            if(!System.Text.RegularExpressions.Regex.IsMatch(sid,@"\AS-1-5-21-\d+-\d+-\d+-1001\z")||r.IdentityBefore["Class11"].Split('|').Length!=1||!r.IdentityBefore["Class11"].StartsWith(sid+":",StringComparison.Ordinal)||new[]{"Class1","Class2","Class4","Class5"}.Any(key=>r.IdentityBefore[key].Split('|').Any(x=>x==sid||x.StartsWith(sid+":",StringComparison.Ordinal))))throw new InvalidOperationException("Default DACL target must be the sole unique restricting SID, not a caller identity/group");
            var added=new CommonAce(AceFlags.None,AceQualifier.AccessAllowed,0x10000000,unique,false,null);
            byte[] ace=new byte[added.BinaryLength];added.GetBinaryForm(ace,0);
            byte[] original=Convert.FromBase64String(r.Before.RawAclBase64);
            int end=8+r.Before.Aces.Sum(x=>Convert.FromBase64String(x.RawBase64).Length);
            int size=checked(original.Length+ace.Length),count=checked(r.Before.Aces.Count+1);
            if(size>ushort.MaxValue||count>ushort.MaxValue)throw new InvalidOperationException("Default ACL append exceeds native size");
            byte[] updated=new byte[size];Buffer.BlockCopy(original,0,updated,0,end);Buffer.BlockCopy(ace,0,updated,end,ace.Length);
            Buffer.BlockCopy(original,end,updated,end+ace.Length,original.Length-end);
            updated[2]=(byte)size;updated[3]=(byte)(size>>8);updated[4]=(byte)count;updated[5]=(byte)(count>>8);
            acl=Marshal.AllocHGlobal(size);Marshal.Copy(updated,0,acl,size);
            info=Marshal.AllocHGlobal(IntPtr.Size);Marshal.WriteIntPtr(info,acl);
            DaclCheck(r,SetTokenDefaultDacl(token,6,info,(uint)IntPtr.Size),"SetTokenInformation NEW token TokenDefaultDacl class 6 append unique SID GA");
            r.After=ReadDefaultDacl(r,token,"after");RequireExactAclReadback(r,updated);r.IdentityAfter=UnchangedTokenFields(r,token,"after");
            r.OriginalAcesUnchanged=r.After.Aces.Count==count&&r.Before.Aces.Select((x,i)=>x.RawBase64==r.After.Aces[i].RawBase64).All(x=>x);
            r.OnlyIntendedAceAdded=r.After.Aces.Count==count&&r.After.Aces[count-1].RawBase64==Convert.ToBase64String(ace)&&r.After.Aces.Count(x=>x.Sid==sid)==1;
            r.OtherTokenFieldsUnchanged=r.IdentityBefore.Count==r.IdentityAfter.Count&&r.IdentityBefore.All(x=>r.IdentityAfter.ContainsKey(x.Key)&&r.IdentityAfter[x.Key]==x.Value);
            if(!r.OriginalAcesUnchanged||!r.OnlyIntendedAceAdded||!r.OtherTokenFieldsUnchanged)throw new InvalidOperationException("New-token default DACL correction readback mismatch");
        } finally {if(info!=IntPtr.Zero)Marshal.FreeHGlobal(info);if(acl!=IntPtr.Zero)Marshal.FreeHGlobal(acl);r.AllocationsFreed=true;}
    }
    static void Verify(Identity r,string sid) {
        if(!r.Restricted || r.IntegritySid!="S-1-16-4096" || !r.RestrictingSids.Contains(sid)) throw new InvalidOperationException("Token containment verification failed");
        // DISABLE_MAX_PRIVILEGE leaves SeChangeNotifyPrivilege (LUID 23) enabled.
        if(r.EnabledPrivilegeLuids.Any(x=>x!="23")) throw new InvalidOperationException("Unexpected enabled token privilege");
    }
    static Identity ProcessIdentity(IntPtr p,uint pid,IntPtr job) {
        IntPtr t; Check(OpenProcessToken(p,8,out t),"OpenProcessToken child "+pid);
        Identity r; try{r=TokenIdentity(t);}finally{Check(CloseHandle(t),"CloseHandle inspected child token");}
        r.Pid=pid; bool inJob; Check(IsProcessInJob(p,job,out inJob),"IsProcessInJob"); r.InJob=inJob;
        StringBuilder b=new StringBuilder(32768); uint n=(uint)b.Capacity; Check(QueryFullProcessImageName(p,0,b,ref n),"QueryFullProcessImageName"); r.Image=b.ToString(); return r;
    }
    public static string SecuritySddl(string path) {
        IntPtr o,g,d,s,sd; uint rc=GetNamedSecurityInfo(path,1,0x14,out o,out g,out d,out s,out sd);
        if(rc!=0) throw new Win32Exception((int)rc,"GetNamedSecurityInfo DACL+LABEL "+path);
        try{IntPtr text;uint n;Check(ConvertSecurityDescriptorToStringSecurityDescriptor(sd,1,0x14,out text,out n),"SecurityDescriptorToString");try{return Marshal.PtrToStringUni(text);}finally{FreeLocal(text,"filesystem SDDL");}}
        finally{FreeLocal(sd,"filesystem descriptor");}
    }
    static void RuntimeAcl(string runtime,string sid) {
        var info=new DirectoryInfo(runtime); var acl=info.GetAccessControl();
        acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(sid),FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
        info.SetAccessControl(acl);
        IntPtr sd; uint size; Check(ConvertStringSecurityDescriptorToSecurityDescriptor("S:(ML;OICI;NW;;;LW)",1,out sd,out size),"Convert low label");
        try{bool present,def;IntPtr sacl;Check(GetSecurityDescriptorSacl(sd,out present,out sacl,out def),"GetSecurityDescriptorSacl");uint rc=SetNamedSecurityInfo(runtime,1,0x10,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,sacl);if(rc!=0)throw new Win32Exception((int)rc,"SetNamedSecurityInfo low runtime label");}finally{FreeLocal(sd,"runtime low label descriptor");}
    }
    static void SetJob<T>(IntPtr job,int cls,T value) {
        int n=Marshal.SizeOf(typeof(T));IntPtr p=Marshal.AllocHGlobal(n);try{Marshal.StructureToPtr(value,p,false);Check(SetInformationJobObject(job,cls,p,(uint)n),"SetInformationJobObject "+cls);}finally{Marshal.FreeHGlobal(p);}
    }
    static uint Active(IntPtr job) {
        int n=Marshal.SizeOf(typeof(BASIC_ACCOUNTING));IntPtr p=Marshal.AllocHGlobal(n);try{Check(QueryInformationJobObject(job,1,p,(uint)n,IntPtr.Zero),"QueryJob accounting");return ((BASIC_ACCOUNTING)Marshal.PtrToStructure(p,typeof(BASIC_ACCOUNTING))).active;}finally{Marshal.FreeHGlobal(p);}
    }
    static uint Limits(IntPtr job) {
        int n=Marshal.SizeOf(typeof(EXTENDED_LIMIT));IntPtr p=Marshal.AllocHGlobal(n);try{Check(QueryInformationJobObject(job,9,p,(uint)n,IntPtr.Zero),"QueryJob limits");return ((EXTENDED_LIMIT)Marshal.PtrToStructure(p,typeof(EXTENDED_LIMIT))).basic.flags;}finally{Marshal.FreeHGlobal(p);}
    }
    static IntPtr OpenIo(string role,string path,bool input,Receipt r) {
        SECURITY_ATTRIBUTES sa=new SECURITY_ATTRIBUTES{length=(uint)Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),inherit=true};
        IntPtr h=CreateFile(path,input?0x80000000u:0x40000000u,1,ref sa,input?3u:1u,0x80,IntPtr.Zero);
        Check(h!=new IntPtr(-1),"CreateFile private "+role);
        IoHandle item=new IoHandle{Role=role,Path=path,Access=input?"GENERIC_READ":"GENERIC_WRITE",Handle=h.ToInt64()};r.HandleAllowlist.Add(item);
        uint flags;Check(GetHandleInformation(h,out flags),"GetHandleInformation "+role);item.FlagsBeforeLaunch=flags;item.FileType=GetFileType(h);
        if((flags&1)==0||item.FileType!=1)throw new InvalidOperationException("Invalid inheritable private disk handle "+role);
        return h;
    }
    static string Quote(string arg) { return "\""+System.Text.RegularExpressions.Regex.Replace(System.Text.RegularExpressions.Regex.Replace(arg,@"(\\*)\""", "$1$1\\\""),@"(\\+)$","$1$1")+"\""; }
    static string EventName(uint msg) { switch(msg){case 4:return "ACTIVE_PROCESS_ZERO";case 6:return "NEW_PROCESS";case 7:return "EXIT_PROCESS";case 8:return "ABNORMAL_EXIT_PROCESS";default:return "JOB_MESSAGE_"+msg;} }

    // Owned lab-only USER objects. No access/security mutation of the original station.
    sealed class PrivateWindows {
        [DllImport("kernel32.dll")] static extern void SetLastError(uint error);
        [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorControl(IntPtr sd,out ushort control,out uint revision);
        [DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateWindowStation(string name,uint flags,uint access,ref SECURITY_ATTRIBUTES sa);
        [DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateDesktopEx(string name,IntPtr device,IntPtr mode,uint flags,uint access,ref SECURITY_ATTRIBUTES sa,uint heap,IntPtr reserved);
        [DllImport("user32.dll",SetLastError=true)] static extern IntPtr GetProcessWindowStation();
        [DllImport("user32.dll",SetLastError=true)] static extern bool SetProcessWindowStation(IntPtr station);
        [DllImport("user32.dll",SetLastError=true)] static extern bool CloseWindowStation(IntPtr station);
        [DllImport("user32.dll",SetLastError=true)] static extern bool CloseDesktop(IntPtr desktop);
        [DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool GetUserObjectInformation(IntPtr h,int index,IntPtr data,uint size,out uint needed);
        [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorDacl(IntPtr sd,out bool present,out IntPtr acl,out bool def);
        [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetAce(IntPtr acl,uint index,out IntPtr ace);
        [DllImport("advapi32.dll")] static extern uint GetSecurityInfo(IntPtr h,int type,uint info,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr sd);
        const uint StationAccess=0x000f037f, DesktopAccess=0x000f01ff;
        readonly WindowObjects r;
        IntPtr original,station,desktop;
        public PrivateWindows(WindowObjects receipt) {r=receipt;}
        void Result(bool ok,string api) {
            int error=ok?0:Marshal.GetLastWin32Error();r.Operations.Add(api+": Win32="+error);
            if(!ok)throw new Win32Exception(error,api);
        }
        string Name(IntPtr h) {
            uint size;bool sizing=GetUserObjectInformation(h,2,IntPtr.Zero,0,out size);int error=sizing?0:Marshal.GetLastWin32Error();
            r.Operations.Add("GetUserObjectInformation NAME size: Win32="+error);
            if(sizing||error!=122||size<2||size>65536||size%2!=0)throw new Win32Exception(error,"Invalid USER name sizing result");
            uint capacity=size;IntPtr p=Marshal.AllocHGlobal((int)capacity);
            try{Result(GetUserObjectInformation(h,2,p,capacity,out size),"GetUserObjectInformation NAME");if(size<2||size>capacity||size%2!=0||Marshal.ReadInt16(p,(int)size-2)!=0)throw new InvalidOperationException("Invalid USER name length/termination");return Marshal.PtrToStringUni(p,(int)size/2-1);}finally{Marshal.FreeHGlobal(p);}
        }
        string Security(IntPtr h,bool verify,string user,string sid,uint mask) {
            IntPtr o,g,d,s,sd;uint rc=GetSecurityInfo(h,7,0x17,out o,out g,out d,out s,out sd); // SE_WINDOW_OBJECT; OWNER|GROUP|DACL|LABEL, not privileged SACL query.
            r.Operations.Add("GetSecurityInfo WINDOW OWNER|GROUP|DACL|LABEL: Win32="+rc);
            if(rc!=0)throw new Win32Exception((int)rc,"GetSecurityInfo window object");
            try {
                IntPtr text;uint size;Result(ConvertSecurityDescriptorToStringSecurityDescriptor(sd,1,0x17,out text,out size),"Window security SDDL");
                string value;try{value=Marshal.PtrToStringUni(text);}finally{FreeLocal(text,"window SDDL");}
                if(verify) {
                    if(SidText(o)!=user)throw new InvalidOperationException("New object owner mismatch");
                    ushort control;uint revision;Result(GetSecurityDescriptorControl(sd,out control,out revision),"Window descriptor control");if((control&0x1000)==0)throw new InvalidOperationException("New object DACL is not protected");
                    bool present,def;IntPtr acl;Result(GetSecurityDescriptorDacl(sd,out present,out acl,out def),"Window DACL");
                    if(!present||acl==IntPtr.Zero||Marshal.ReadInt16(acl,4)!=2)throw new InvalidOperationException("New object DACL must contain exactly two ACEs");
                    var expected=new HashSet<string>(new[]{user,sid});
                    for(uint i=0;i<2;i++) {IntPtr ace;Result(GetAce(acl,i,out ace),"Window DACL ACE");if(Marshal.ReadByte(ace)!=0||Marshal.ReadByte(ace,1)!=0||unchecked((uint)Marshal.ReadInt32(ace,4))!=mask||!expected.Remove(SidText(IntPtr.Add(ace,8))))throw new InvalidOperationException("Unexpected new object DACL ACE");}
                    Result(GetSecurityDescriptorSacl(sd,out present,out acl,out def),"Window LABEL");
                    if(!present||acl==IntPtr.Zero||Marshal.ReadInt16(acl,4)!=1)throw new InvalidOperationException("New object must have one low mandatory label");
                    IntPtr ml;Result(GetAce(acl,0,out ml),"Window LABEL ACE");
                    if(Marshal.ReadByte(ml)!=0x11||Marshal.ReadByte(ml,1)!=0||Marshal.ReadInt32(ml,4)!=1||SidText(IntPtr.Add(ml,8))!="S-1-16-4096")throw new InvalidOperationException("Unexpected new object mandatory label");
                }
                return value;
            } finally{FreeLocal(sd,"window readback descriptor");}
        }
        SECURITY_ATTRIBUTES Attributes(string user,string sid,uint access,out IntPtr sd) {
            uint size;string sddl="O:"+user+"D:P(A;;0x"+access.ToString("X")+";;;"+user+")(A;;0x"+access.ToString("X")+";;;"+sid+")S:(ML;;NW;;;LW)";
            Result(ConvertStringSecurityDescriptorToSecurityDescriptor(sddl,1,out sd,out size),"Convert owned window creation DACL+low LABEL");
            return new SECURITY_ATTRIBUTES{length=(uint)Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),descriptor=sd,inherit=false};
        }
        void Restore(string phase) {
            if(original==IntPtr.Zero)return;
            Result(SetProcessWindowStation(original),"SetProcessWindowStation restore "+phase);
            IntPtr current=GetProcessWindowStation();Result(current!=IntPtr.Zero,"GetProcessWindowStation restore "+phase);
            if(current!=original||Name(current)!=r.OriginalName)throw new InvalidOperationException("Original station restoration mismatch");
            r.OriginalAfterSddl=Security(current,false,null,null,0);
            r.OriginalUnchanged=r.OriginalAfterSddl==r.OriginalBeforeSddl;
            if(!r.OriginalUnchanged)throw new InvalidOperationException("Original window station metadata changed");
        }
        public void Setup(string user,string sid,string helperPath) {
            r.HelperPid=(uint)Process.GetCurrentProcess().Id;
            string[] command=Environment.GetCommandLineArgs();
            int file=Array.FindIndex(command,x=>string.Equals(x,"-File",StringComparison.OrdinalIgnoreCase));
            if(file<0||file+1>=command.Length||!Path.IsPathRooted(helperPath)||!string.Equals(Path.GetFullPath(command[file+1]),Path.GetFullPath(helperPath),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Private station switch requires dedicated -File helper process");
            original=GetProcessWindowStation();Result(original!=IntPtr.Zero,"GetProcessWindowStation original");r.OriginalHandle=original.ToInt64();r.OriginalName=Name(original);r.OriginalBeforeSddl=Security(original,false,null,null,0);
            r.StationName="PiLabBoundary_"+Guid.NewGuid().ToString("N");r.DesktopName="Desktop_"+Guid.NewGuid().ToString("N");
            try {
                IntPtr sd;SECURITY_ATTRIBUTES sa=Attributes(user,sid,StationAccess,out sd);
                try {SetLastError(0);station=CreateWindowStation(r.StationName,1,StationAccess,ref sa);int error=Marshal.GetLastWin32Error();r.Operations.Add("CreateWindowStation "+r.StationName+": Win32="+error);if(station==IntPtr.Zero)throw new Win32Exception(error,"CreateWindowStation");if(error!=0)throw new Win32Exception(error,"CreateWindowStation unexpected creation result");}
                finally {FreeLocal(sd,"window station creation descriptor");}
                r.StationSddl=Security(station,true,user,sid,StationAccess);
                IntPtr flags=Marshal.AllocHGlobal(12);try{uint needed;Result(GetUserObjectInformation(station,1,flags,12,out needed),"WindowStation FLAGS");r.NonInteractive=(Marshal.ReadInt32(flags,8)&1)==0;if(!r.NonInteractive)throw new InvalidOperationException("New station unexpectedly visible");}finally{Marshal.FreeHGlobal(flags);}
                Result(SetProcessWindowStation(station),"SetProcessWindowStation owned station");
                sa=Attributes(user,sid,DesktopAccess,out sd);
                try {SetLastError(0);desktop=CreateDesktopEx(r.DesktopName,IntPtr.Zero,IntPtr.Zero,0,DesktopAccess,ref sa,0,IntPtr.Zero);int error=Marshal.GetLastWin32Error();r.Operations.Add("CreateDesktopEx "+r.DesktopName+": Win32="+error);if(desktop==IntPtr.Zero)throw new Win32Exception(error,"CreateDesktopEx");if(error==183){IntPtr collision=desktop;desktop=IntPtr.Zero;Result(CloseDesktop(collision),"CloseDesktop collision handle (not owned)");throw new Win32Exception(error,"Desktop collision refused");}if(error!=0)throw new Win32Exception(error,"CreateDesktopEx unexpected creation result");}
                finally {FreeLocal(sd,"desktop creation descriptor");}
                r.DesktopSddl=Security(desktop,true,user,sid,DesktopAccess);
                if(Name(station)!=r.StationName||Name(desktop)!=r.DesktopName)throw new InvalidOperationException("Owned object name mismatch");
                r.DesktopBinding=r.StationName+"\\"+r.DesktopName;
            } finally {Restore("setup finally");}
        }
        public void VerifyRestored() {Restore("before launch");r.RestoredBeforeLaunch=true;}
        public void Cleanup(bool safe) {
            try {Restore("unconditional finally");r.RestoredFinally=original!=IntPtr.Zero;}
            finally {
                if(!safe)throw new InvalidOperationException("Owned objects retained: Job/process not proven empty");
                Exception failure=null;
                try{if(desktop!=IntPtr.Zero){Result(CloseDesktop(desktop),"CloseDesktop owned");r.DesktopClosed=true;desktop=IntPtr.Zero;}}catch(Exception e){failure=e;}
                try{if(station!=IntPtr.Zero){Result(CloseWindowStation(station),"CloseWindowStation owned");r.StationClosed=true;station=IntPtr.Zero;}}catch(Exception e){failure=failure==null?e:new AggregateException(failure,e);}
                if(failure!=null)throw failure;
            }
        }
    }

    static void CloseOwned(Receipt r,IntPtr h,string role) {
        bool ok=CloseHandle(h);int error=ok?0:Marshal.GetLastWin32Error();
        r.CleanupResults.Add(new DaclApi{Api="CloseHandle "+role,Success=ok,Win32Error=error});
        if(!ok){r.Status="FAILED";r.Error+="\nCLEANUP: CloseHandle "+role+" Win32="+error;}
    }
    static void FreeOwnedLocal(Receipt r,IntPtr p,string role) {
        IntPtr remaining=LocalFree(p);bool ok=remaining==IntPtr.Zero;int error=ok?0:Marshal.GetLastWin32Error();
        r.CleanupResults.Add(new DaclApi{Api="LocalFree "+role,Success=ok,Win32Error=error});
        if(!ok){r.Status="FAILED";r.Error+="\nCLEANUP: LocalFree "+role+" Win32="+error;}
    }
    // All ACL changes apply to this fresh runtime only; callers must enforce its private evidence location.
    public static Receipt Run(string executable,string[] args,string runtime,string canary,string sid,Dictionary<string,string> environment,int timeoutMs,bool dummy,string consoleMode,string stdinText,string helperPath) {
        Receipt r=new Receipt();r.RestrictingSid=sid;r.ConsoleMode=consoleMode;
        IntPtr caller=IntPtr.Zero,token=IntPtr.Zero,rsid=IntPtr.Zero,low=IntPtr.Zero,job=IntPtr.Zero,port=IntPtr.Zero,env=IntPtr.Zero;
        PROCESS_INFORMATION pi=new PROCESS_INFORMATION();bool assigned=false,resumed=false,attributesInitialized=false;
        IntPtr attributeList=IntPtr.Zero,handleArray=IntPtr.Zero;
        Dictionary<uint,IntPtr> handles=new Dictionary<uint,IntPtr>(); Stopwatch clock=Stopwatch.StartNew();
        PrivateWindows windows=new PrivateWindows(r.Windows);
        try {
            RuntimeAcl(runtime,sid);r.RuntimeSddl=SecuritySddl(runtime);r.CanarySddl=SecuritySddl(canary);
            if(!r.RuntimeSddl.Contains(";;;LW)"))throw new InvalidOperationException("Low runtime label not present");
            Check(OpenProcessToken(GetCurrentProcess(),CallerTokenAccess,out caller),"OpenProcessToken caller QUERY_SOURCE|QUERY|DUPLICATE|ASSIGN_PRIMARY|ADJUST_DEFAULT");
            Check(ConvertStringSidToSid(sid,out rsid),"Convert restricting SID");
            SID_AND_ATTRIBUTES restriction=new SID_AND_ATTRIBUTES{Sid=rsid};
            Check(CreateRestrictedToken(caller,1|8,0,IntPtr.Zero,0,IntPtr.Zero,1,ref restriction,out token),"CreateRestrictedToken DISABLE_MAX_PRIVILEGE|WRITE_RESTRICTED");
            Check(ConvertStringSidToSid("S-1-16-4096",out low),"Convert low integrity SID");
            SID_AND_ATTRIBUTES label=new SID_AND_ATTRIBUTES{Sid=low,Attributes=0x20};
            Check(SetTokenInformation(token,25,ref label,(uint)Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES))+GetLengthSid(low)),"SetTokenInformation low integrity");
            r.PreparedToken=TokenIdentity(token);Verify(r.PreparedToken,sid);r.LowIntegrity=true;
            CorrectNewTokenDacl(token,sid,r.DefaultDacl);
            windows.Setup(r.PreparedToken.UserSid,sid,helperPath);
            job=CreateJobObject(IntPtr.Zero,null);Check(job!=IntPtr.Zero,"CreateJobObject");
            EXTENDED_LIMIT limits=new EXTENDED_LIMIT();limits.basic.flags=0x2000; // KILL_ON_JOB_CLOSE only; neither breakaway flag.
            SetJob(job,9,limits);r.JobLimitFlags=Limits(job);if(r.JobLimitFlags!=0x2000)throw new InvalidOperationException("Unexpected Job limits");
            port=CreateIoCompletionPort(new IntPtr(-1),IntPtr.Zero,IntPtr.Zero,1);Check(port!=IntPtr.Zero,"CreateIoCompletionPort");
            SetJob(job,7,new COMPLETION_ASSOC{key=new IntPtr(1),port=port});
            string block=string.Join("\0",environment.OrderBy(x=>x.Key,StringComparer.OrdinalIgnoreCase).Select(x=>x.Key+"="+x.Value).ToArray())+"\0\0";
            env=Marshal.StringToHGlobalUni(block);STARTUPINFOEX startup=new STARTUPINFOEX();startup.startup.cb=(uint)Marshal.SizeOf(typeof(STARTUPINFOEX));
            if(consoleMode!="Detached")throw new ArgumentException("Repaired I/O runner requires Detached mode");
            string stdinPath=Path.Combine(runtime,"stdin.txt");
            File.WriteAllText(stdinPath,stdinText??"",new UTF8Encoding(false));
            startup.startup.flags=0x100; // STARTF_USESTDHANDLES with valid private file handles.
            startup.startup.input=OpenIo("stdin",stdinPath,true,r);
            startup.startup.output=OpenIo("stdout",Path.Combine(runtime,"stdout.txt"),false,r);
            startup.startup.error=OpenIo("stderr",Path.Combine(runtime,"stderr.txt"),false,r);
            IntPtr attributeBytes=IntPtr.Zero;
            bool sizing=InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref attributeBytes);
            if(sizing||Marshal.GetLastWin32Error()!=122||attributeBytes==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"InitializeProcThreadAttributeList size");
            attributeList=Marshal.AllocHGlobal(attributeBytes);
            Check(InitializeProcThreadAttributeList(attributeList,1,0,ref attributeBytes),"InitializeProcThreadAttributeList");attributesInitialized=true;
            handleArray=Marshal.AllocHGlobal(3*IntPtr.Size);
            Marshal.WriteIntPtr(handleArray,0,startup.startup.input);Marshal.WriteIntPtr(handleArray,IntPtr.Size,startup.startup.output);Marshal.WriteIntPtr(handleArray,2*IntPtr.Size,startup.startup.error);
            Check(UpdateProcThreadAttribute(attributeList,0,new IntPtr(0x20002),handleArray,new IntPtr(3*IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"UpdateProcThreadAttribute HANDLE_LIST");
            startup.attributes=attributeList;r.HandleListApplied=true;
            r.CreationFlags=4|0x400|8|0x80000; // SUSPENDED | UNICODE_ENVIRONMENT | DETACHED_PROCESS | EXTENDED_STARTUPINFO_PRESENT
            r.StartupFlags=startup.startup.flags;r.StandardInput=startup.startup.input.ToInt64();r.StandardOutput=startup.startup.output.ToInt64();r.StandardError=startup.startup.error.ToInt64();
            windows.VerifyRestored();
            startup.startup.desktop=r.Windows.DesktopBinding; // Only startup desktop changes; flags/stdio/token/Job remain fixed.
            string command=Quote(executable)+" "+string.Join(" ",args.Select(Quote).ToArray());
            Check(CreateProcessAsUser(token,executable,new StringBuilder(command),IntPtr.Zero,IntPtr.Zero,true,r.CreationFlags,env,runtime,ref startup,out pi),"CreateProcessAsUser suspended restricted primary Detached HANDLE_LIST");
            r.RootPid=pi.pid;r.InheritHandles=true; // Required by HANDLE_LIST: only these three handles may inherit.
            foreach(IoHandle item in r.HandleAllowlist){IntPtr h=new IntPtr(item.Handle);Check(SetHandleInformation(h,1,0),"Clear parent inherit "+item.Role);uint f;Check(GetHandleInformation(h,out f),"Verify cleared inherit "+item.Role);item.FlagsAfterLaunch=f;if((f&1)!=0)throw new InvalidOperationException("Parent handle still inheritable");}
            Check(AssignProcessToJobObject(job,pi.process),"AssignProcessToJobObject before resume");assigned=true;r.AssignedBeforeResume=true;
            Identity root=ProcessIdentity(pi.process,pi.pid,job);Verify(root,sid);if(!root.InJob)throw new InvalidOperationException("Root not in Job");
            r.Processes.Add(root);handles.Add(pi.pid,pi.process);
            Check(ResumeThread(pi.thread)!=0xffffffff,"ResumeThread");resumed=true;r.Status="FAILED";
            bool zero=false;
            while(clock.ElapsedMilliseconds<timeoutMs) {
                uint msg;IntPtr key,value;
                if(!GetQueuedCompletionStatus(port,out msg,out key,out value,200)) {int error=Marshal.GetLastWin32Error();if(error==258)continue;throw new Win32Exception(error,"GetQueuedCompletionStatus");}
                if(key!=new IntPtr(1))throw new InvalidOperationException("Unknown Job completion key");
                r.Events.Add(new Event{ElapsedMs=clock.ElapsedMilliseconds,Message=msg,PidOrValue=value.ToInt64(),Name=EventName(msg)});
                if(msg==6) {
                    uint pid=unchecked((uint)value.ToInt64());
                    if(!handles.ContainsKey(pid)) {
                        IntPtr p=OpenProcess(0x1000|0x100000,false,pid);Check(p!=IntPtr.Zero,"OpenProcess new Job PID "+pid);
                        handles.Add(pid,p);Identity child=ProcessIdentity(p,pid,job);r.Processes.Add(child);Verify(child,sid);
                        if(!child.InJob)throw new InvalidOperationException("Descendant outside Job");
                    }
                    if(dummy)File.WriteAllText(Path.Combine(runtime,"verified-"+pid),"token and Job independently inspected");
                }
                if(msg==4) {zero=true;break;}
            }
            r.ActiveAtClose=Active(job);r.JobEmpty=zero&&r.ActiveAtClose==0;
            if(!r.JobEmpty)throw new TimeoutException("Job did not naturally reach ACTIVE_PROCESS_ZERO within bound");
            foreach(Identity identity in r.Processes) {
                Check(WaitForSingleObject(handles[identity.Pid],0)==0,"WaitForSingleObject natural terminal");
                uint code;Check(GetExitCodeProcess(handles[identity.Pid],out code),"GetExitCodeProcess");identity.ExitCode=code;identity.ExitCodeHex="0x"+code.ToString("X8");
            }
            foreach(Identity identity in r.Processes) {
                if(identity.ExitCode!=0) {
                    if(identity.ExitCode==0xc0000142)r.Status="BLOCKED_RUNNER_UNAVAILABLE";
                    throw new InvalidOperationException("Process "+identity.Pid+" natural exit "+identity.ExitCode+" ("+identity.ExitCodeHex+")");
                }
                if(!r.Events.Any(e=>(e.Message==7||e.Message==8)&&e.PidOrValue==identity.Pid))throw new InvalidOperationException("Missing Job exit event for "+identity.Pid);
            }
            if(dummy&&r.Processes.Count(p=>string.Equals(p.Image,executable,StringComparison.OrdinalIgnoreCase))!=2)throw new InvalidOperationException("Expected one dummy root and one Node descendant");
            r.Status="NATIVE_RUN_COMPLETE";
        } catch(Exception e) { r.Error=e.ToString(); if(e is Win32Exception)r.ErrorWin32Code=((Win32Exception)e).NativeErrorCode; if(resumed&&r.Status!="BLOCKED_RUNNER_UNAVAILABLE")r.Status="FAILED"; }
        finally {
            if(pi.process!=IntPtr.Zero&&!r.JobEmpty) {
                r.ForcedCleanup=true;
                try {
                    Check(assigned?TerminateJobObject(job,0xdead):TerminateProcess(pi.process,0xdead),"Error cleanup terminate");
                    if(assigned){Stopwatch wait=Stopwatch.StartNew();while(Active(job)!=0&&wait.ElapsedMilliseconds<10000)System.Threading.Thread.Sleep(50);r.ActiveAtClose=Active(job);r.JobEmpty=r.ActiveAtClose==0;}
                    else Check(WaitForSingleObject(pi.process,10000)==0,"Cleanup wait unassigned process");
                }catch(Exception cleanup){r.Error+="\nCLEANUP: "+cleanup;}
            }
            try { windows.Cleanup(pi.process==IntPtr.Zero || (assigned&&r.JobEmpty) || (!assigned&&WaitForSingleObject(pi.process,0)==0)); }
            catch(Exception cleanup) {r.Status="BLOCKED_RUNNER_UNAVAILABLE";r.Error+="\nWINDOW CLEANUP: "+cleanup;if(cleanup is Win32Exception)r.ErrorWin32Code=((Win32Exception)cleanup).NativeErrorCode;}
            foreach(IoHandle item in r.HandleAllowlist){item.Closed=CloseHandle(new IntPtr(item.Handle));if(!item.Closed){r.Status="BLOCKED_RUNNER_UNAVAILABLE";r.Error+="\nCloseHandle private "+item.Role+" failed: "+Marshal.GetLastWin32Error();}}
            if(attributesInitialized)DeleteProcThreadAttributeList(attributeList);
            if(attributeList!=IntPtr.Zero)Marshal.FreeHGlobal(attributeList);if(handleArray!=IntPtr.Zero)Marshal.FreeHGlobal(handleArray);
            foreach(IntPtr h in handles.Values)CloseOwned(r,h,"process");
            if(pi.process!=IntPtr.Zero&&!handles.ContainsKey(pi.pid))CloseOwned(r,pi.process,"unregistered root process");
            if(pi.thread!=IntPtr.Zero)CloseOwned(r,pi.thread,"root thread");
            if(job!=IntPtr.Zero)CloseOwned(r,job,"Job");if(port!=IntPtr.Zero)CloseOwned(r,port,"completion port");
            if(token!=IntPtr.Zero)CloseOwned(r,token,"NEW restricted token");if(caller!=IntPtr.Zero)CloseOwned(r,caller,"caller query token");
            if(rsid!=IntPtr.Zero)FreeOwnedLocal(r,rsid,"restricting SID");if(low!=IntPtr.Zero)FreeOwnedLocal(r,low,"low SID");if(env!=IntPtr.Zero)Marshal.FreeHGlobal(env);
        }
        return r;
    }
}
