{ config, lib, ... }:

let
  cfg = config.fleet.service.fastmail-meeting-nudger;
in
{
  options.fleet.service.fastmail-meeting-nudger.enable =
    lib.mkEnableOption "the Fastmail meeting nudger";

  config = lib.mkIf cfg.enable {
    age.secrets = {
      github-pat = {
        file = ../secrets/github-pat.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      edge-6201-fastmail-meeting-nudger-env = {
        file = ../secrets/edge-6201-fastmail-meeting-nudger-env.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/fastmail-meeting-nudger 0750 10001 10001 -"
    ];

    virtualisation.oci-containers.containers.fastmail-meeting-nudger = {
      image = "ghcr.io/chadwagoner/fastmail-meeting-nudger:2026.10.11";
      login = {
        registry = "ghcr.io";
        username = "chadwagoner";
        passwordFile = config.age.secrets.github-pat.path;
      };
      environmentFiles = [
        config.age.secrets.edge-6201-fastmail-meeting-nudger-env.path
      ];
      environment = {
        REPORT_TO = "";
        ORGANIZER_EMAILS = "";
        CALENDAR_NAMES = "Work";
        CALDAV_URL = "https://caldav.fastmail.com/dav/";
        SMTP_HOST = "smtp.fastmail.com";
        SMTP_PORT = "465";
        DRY_RUN = "true";
        REMINDER_INCLUDE_ICS = "false";
        TZ = "UTC";
        SCHEDULE_TIME = "11:00";
        HISTORY_RETENTION_DAYS = "30";
        DATABASE_PATH = "/data/nudger.sqlite3";
      };
      volumes = [
        "/var/lib/fastmail-meeting-nudger:/data"
      ];
    };
  };
}
