
class atftp::config {

  $sysconfig_atftpd = "/etc/sysconfig/atftpd"

  File {
    require => Class["atftp::install"],
    notify  => Class["atftp::service"]
  }

  file {$sysconfig_atftpd:
    ensure  => present,
    owner   => "root",
    group   => "root",
    mode    => 600,
    content => template("atftp$sysconfig_atftpd")
  }

  file {$atftp::atftp_dir:
    ensure  => directory,
    owner   => "root",
    group   => "root",
    mode    => 755
  }

}
