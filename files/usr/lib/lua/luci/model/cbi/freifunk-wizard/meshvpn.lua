local meshvpn_name = "mesh_vpn"

local uci = luci.model.uci.cursor()
local nav = require "luci.tools.freifunk-wizard.nav"

local f = SimpleForm("meshvpn", "Verein-VPN", "<p>Um dein Freifunkger&auml;t auch \
&uuml;ber das Internet mit dem Freifunk-Netzwerk zu verbinden, kann ein \
Verein-VPN aktiviert werden. Dies erlaubt es, das Ger&auml;t auch zu betreiben, \
wenn es keine anderen Ger&auml;te in deiner Umgebung gibt, mit denen eine \
WLAN-Verbindung m&ouml;glich ist.</p><p>Dabei wird zur Kommunikation ein \
verschl&uuml;sselter Tunnel verwendet, sodass f&uuml;r den Anschluss-Inhaber \
keinerlei Risiken entstehen.</p><p>Wenn du mehr dar&uuml;ber erfahren \
m&ouml;chtest, klicke <a href=\"http://freifunk-nrw.de/mitmachen\">hier</a>.</p> \
<p>Damit der Verein-VPN deine Internet-Verbindung nicht \
unverh&auml;ltnism&auml;&szlig;ig auslastet, kann die Bandbreite begrenzt werden. \
Wenn du zum Beispiel eine DSL-16000-Leitung hast und maximal ein Viertel der \
Leitung zur Verf&uuml;gung stellen willst, muss als Downstream-Bandbreite \
4000&nbsp;kbit/s eingetragen werden.</p><p>Um das Freifunk-Netz nicht zu sehr \
auszubremsen, bitten wir darum, mindestens 2000&nbsp;kbit/s im Downstream und \
200&nbsp;kbit/s im Upstream bereitzustellen.</p>")
f.template = "freifunk-wizard/wizardform"

meshvpn = f:field(Flag, "meshvpn", "Verein-VPN aktivieren")
meshvpn.default = string.format("%d", uci:get("fastd", meshvpn_name, "enabled", "0"))
meshvpn.rmempty = false

tc = f:field(Flag, "tc", "Bandbreitenbegrenzung aktivieren")
tc.default = string.format("%d", uci:get_first("freifunk", "bandwidth", "enabled", "0"))
tc.rmempty = false

downstream = f:field(Value, "downstream", "Downstream-Bandbreite (kbit/s)")
downstream.value = uci:get_first("freifunk", "bandwidth", "downstream", "0")
upstream = f:field(Value, "upstream", "Upstream-Bandbreite (kbit/s)")
upstream.value = uci:get_first("freifunk", "bandwidth", "upstream", "0")

function f.handle(self, state, data)
  if state == FORM_VALID then
    uci:set("fastd", meshvpn_name, "enabled", data.meshvpn)
    uci:save("fastd")
    uci:commit("fastd")

    uci:foreach("freifunk", "bandwidth", function(s)
		if type(data.upstream) ~= "nil" then
			uci:set("freifunk", s[".name"], "upstream", data.upstream)
		else
			uci:set("freifunk", s[".name"], "upstream", "0")
			end
		if type(data.downstream) ~= "nil" then
			uci:set("freifunk", s[".name"], "downstream", data.downstream)
		else
			uci:set("freifunk", s[".name"], "downstream", "0")
			end
		if type(data.tc) ~= "nil" then
			uci:set("freifunk", s[".name"], "enabled", data.tc)
		else
			uci:set("freifunk", s[".name"], "enabled", "0")
			end
		end
    )

    uci:save("freifunk")
    uci:commit("freifunk")

    if data.meshvpn == "1" then
      local secret = uci:get("fastd", meshvpn_name, "secret")
      if not secret or not secret:match("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x") then
        luci.sys.call("/etc/init.d/haveged start")
        local f = io.popen("fastd --generate-key --machine-readable", "r")
        local secret = f:read("*a")
        f:close()
        luci.sys.call("/etc/init.d/haveged stop")

        uci:set("fastd", meshvpn_name, "secret", secret)
        uci:save("fastd")
        uci:commit("fastd")

      end
      luci.http.redirect(luci.dispatcher.build_url("wizard", "meshvpn", "pubkey"))
    else
      nav.maybe_redirect_to_successor()
    end
  end

  return true
end

return f