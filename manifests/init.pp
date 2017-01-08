#
# Mailops Team
#
# Nextcloud module to install and configure nextcloud
#
class nextcloud (
  $dbname      = $::nextcloud::dbname,
  $dbname      = $::nextcloud::dbname,
  $dbuser      = $::nextcloud::dbuser,
  $dbpassword  = $::nextcloud::dbpassword,
  $dbhost      = $::nextcloud::dbhost,
  $dbtype      = $::nextcloud::dbtype,

  $domain      = $::nextcloud::domain,
  $docroot     = $::nextcloud::docroot,
) {
  ## MySQL config
  include '::base::mysql'

  mysql::db { $dbname:
    user       => $dbuser,
    password   => $dbpassword,
    host       => $dbhost,
    grant      => ['ALL'],
  }

  ## Nextcloud config
  include apt

  #TODO: move some variables in hiera
  apt::source { 'nextcloud':
    comment    => 'This is the Nextcloud Debian Repository',
    location   => 'https://repo.morph027.de/nextcloud',
    release    => 'jessie',
    repos      => 'main',
    key        => {
      'id'     => '02BD5FB7BA4650D50ED69002797DFE3F4F80269B',
      'source' => 'https://repo.morph027.de/gpg.key',
    },
    include    => {
      'deb'    => true,
    },
  }

  #TODO: some dependencies are maybe missing here but installed
  # in rainloop module, we need to move them in some common module
  package { 'php7.0-zip': ensure => latest }
  package { 'php7.0-mbstring': ensure => latest }
  package { 'nextcloud-files':
    ensure     => latest,
    require    => Apt::Source['nextcloud'],
  }

  file { $docroot:
    ensure    => directory,
    owner     => 'www-data',
    group     => 'www-data',
  }

  file { "$docroot/.well-known":
    ensure    => directory,
    owner     => 'www-data',
    group     => 'www-data',
    require   => File[$docroot],
  }

  #TODO: update default config.php file
  #file { "$docroot/config/config.php":
  #  owner     => 'www-data',
  #  group     => 'www-data',
  #  content   => template("${module_name}/config"),
  #  require   => Package['nextcloud-files'],
  #}

  ## Nginx config
  include '::base::nginx'

  file { '/etc/nginx/sites-available/nextcloud':
    ensure    => file,
    content   => template("${module_name}/nextcloud"),
    require   => Package['nginx'],
    notify    => Service['nginx'],
  }
  ->
  file { '/etc/nginx/sites-enabled/nextcloud':
    ensure    => link,
    target    => '/etc/nginx/sites-available/nextcloud',
    notify    => Service['nginx'],
  }

  #TODO: move letsencrypt class call in some common file
  # but we need to remove it from mail module first
  #class { ::letsencrypt:
  #  unsafe_registration => true,
  #}

  letsencrypt::certonly { 'nextcloud':
    domains              => [$domain],
    plugin               => 'webroot',
    webroot_paths        => [$docroot],
    manage_cron          => true,
    cron_success_command => '/bin/systemctl reload nginx.service',
  }
}
