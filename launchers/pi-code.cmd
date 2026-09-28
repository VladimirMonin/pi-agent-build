@echo off
setlocal
set "PI_CODING_AGENT_DIR=__PI_PROFILE_DIR_WINDOWS__"
set "PI_AGENT_BUILD_NPM_PREFIX=__NPM_PREFIX_WINDOWS__"
set "PI_CBM_MAX_CONCURRENT_INDEXES=1"
set "PI_CBM_AUTO_REFRESH_INTERVAL_MS=300000"
set "CODEBASE_MEMORY_MCP_BIN=__NPM_PREFIX_WINDOWS__\node_modules\codebase-memory-mcp\bin\codebase-memory-mcp.exe"
call "__NPM_PREFIX_WINDOWS__\pi.cmd" %*
