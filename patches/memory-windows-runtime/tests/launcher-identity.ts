// Read-only identity witness emitted from the launched Pi host, not checker intent.
import {getAgentDir,getPackageDir,VERSION} from '@earendil-works/pi-coding-agent';
export default function(pi){
 pi.on('session_start',()=>{process.stdout.write('PI_BUILD_RUNTIME_IDENTITY '+JSON.stringify({profileDir:getAgentDir(),sdkRoot:getPackageDir(),version:VERSION})+'\n');});
}
