
local pposix_version = "0.3.0";

local pposix = assert(require "util.pposix");
if pposix._VERSION ~= want_pposix_version then log("warn", "Unknown version (%s) of binary pposix module, expected %s", tostring(pposix._VERSION), pposix_version); end

local config_get = require "core.configmanager".get;
local logger_set = require "util.logger".setwriter;

module.host = "*"; -- we're a global module

if not config_get("*", "core", "no_daemonize") then
	local function daemonize_server()
		local logwriter;
		
		local logfilename = config_get("*", "core", "log");
		if logfilename == "syslog" then
			pposix.syslog_open("prosody");
			pposix.syslog_setminlevel(config.get("*", "core", "minimum_log_level") or "info");
				local syslog, format = pposix.syslog_log, string.format;
				logwriter = function (name, level, message, ...)
							if ... then 
								syslog(level, format(message, ...));
							else
								syslog(level, message);
							end
						end;			
		elseif logfilename then
			local logfile = io.open(logfilename, "a+");
			if logfile then
				local write, format, flush = logfile.write, string.format, logfile.flush;
				logwriter = function (name, level, message, ...)
							if ... then 
								write(logfile, name, "\t", level, "\t", format(message, ...), "\n");
							else
								write(logfile, name, "\t" , level, "\t", message, "\n");
							end
							flush(logfile);
						end;
			end
		else
			log("debug", "No logging specified, will continue with default");
		end
		
		local ok, ret = pposix.daemonize();
		if not ok then
			log("error", "Failed to daemonize: %s", ret);
		elseif ret and ret > 0 then
			os.exit(0);
		else
			if logwriter then
				local ok, ret = logger_set(logwriter);
				if not ok then
					log("error", "Couldn't set new log output: %s", ret);
				end
			end
			log("info", "Successfully daemonized to PID %d", pposix.getpid());
			
			local pidfile = config.get("*", "core", "pidfile");
			if pidfile then
				local pf, err = io.open(pidfile, "w+");
				if not pf then
					log("error", "Couldn't write pidfile; %s", err);
				else
					pf:write(tostring(pposix.getpid()));
					pf:close();
				end
			end
		end
	end
	module:add_event_hook("server-starting", daemonize_server);
end
