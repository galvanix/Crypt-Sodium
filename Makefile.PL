use 5.008000;
use ExtUtils::MakeMaker;
use Cwd qw/abs_path/;
use File::Basename qw/dirname/;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $verbose = defined $ARGV[0] && $ARGV[0] eq "verbose";

my $c = {};
chomp(my $pc = `which pkg-config`);
if ($pc) {
    chomp( $c->{libs} = `$pc --libs libsodium` );
    chomp( $c->{cflags} = `$pc --cflags libsodium` );
    chomp( $c->{modversion} = `$pc --modversion libsodium` );
    print "\n[ :D ] Found libsodium $c->{modversion} using pkg-config"
        if $c->{modversion} && $verbose;
}

if (!$c->{modversion}) {
    eval "use Alien::Sodium";
    unless ($@) {
        $c->{libs}   = Alien::Sodium->libs;
        $c->{cflags} = Alien::Sodium->cflags;
        $c->{modversion} = "1.0.8";
        print "\n[ :| ] Found Alien::Sodium -- Assuming it provides libsodium $c->{modversion}\n" if $verbose;
    }
}

my %config = (
    NAME              => 'Crypt::Sodium',
    VERSION_FROM      => 'lib/Crypt/Sodium.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Crypt/Sodium.pm', # retrieve abstract from module
       AUTHOR         => 'Michael Gregorowicz <mike@mg2.org>') : ()),
    LIBS              => $c->{libs},
    DEFINE            => '-std=gnu99 -Wno-pointer-sign', # e.g., '-DHAVE_SOMETHING'
    INC               => "-I. " . $c->{cflags},
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    clean             => {
        # this file is created before building, and should be installed.. but cleaned when 'make clean' is run.
        FILES => 'lib/Crypt/Sodium/BuildVersion.pm',
    },
);

if ($c->{modversion}) {
    $i = 4;
    my ($major, $minor, $revision) = split(/\./, $c->{modversion});
    $config{DEFINE} .= " -DP5CS_LIBMAJ=$major -DP5CS_LIBMIN=$minor -DP5CS_LIBREV=$revision -DP5CS_LIBVER=" . '\"' . $c->{modversion} . '\"';
    write_ver_file($c->{modversion});
    $config{DEFINE} .= " " . extra_define_flags($c->{modversion});
}

WriteMakefile(%config);

sub extra_define_flags {
    my ($lsv) = @_;
    
    my @edefs;
    # version 1.0.9
    # introduced crypto_pwhash_argon2i
    push(@edefs, "-D" . enable_feature(
        '1.0.9',
        P5CS_CPWH => "crypto_pwhash namespace introduced for password hashing functionality", 
    ));
    # introduced "speed record" BLAKE2b and state
    push(@edefs, "-D" . enable_feature(
        '1.0.9',
        P5CS_GH_BLAKE2B => "crypto_generichash_blake2bxx functionality", 
    ));
    # introduced "speed record" BLAKE2b and state
    push(@edefs, "-D" . enable_feature(
        '1.0.9',
        P5CS_GH_BLAKE2B => "crypto_generichash_blake2bxx functionality", 
    ));
    
    # version 1.0.12
    # introduced multiple _keygen() variants for the different algorithms
    push(@edefs, "-D" . enable_feature(
        '1.0.12',
        P5CS_KG_VAR => "xx_keygen and xx_keypair variants present for various algorithms",
    ));
    # introduced ed25519ph; multi-part signature API
    push(@edefs, "-D" . enable_feature(
        '1.0.12',
        P5CS_ED25519PH => "Ed25519ph multi-part signature algorithm functionality",
    ));
    # crypto_kdf present in 1.0.12
    push(@edefs, "-D" . enable_feature(
        '1.0.12',
        P5CS_CKDF => "crypto_kdf namespace available for key derivation functionality",
    ));
    # randombytes_buf_deterministic in 1.0.12
    push(@edefs, "-D" . enable_feature(
        '1.0.12',
        P5CS_DRNG => "randombytes_buf_deterministic psuedo random number generator",
    ));

    return join(' ', @edefs);    
}

sub enable_feature {
    my ($reqver, $def, $desc) = @_;

    my $enable;
    if (vercmp($c->{modversion}, $reqver)) {
        print "[ +++ ] feature $def - ENABLED" if $verbose;
        $enable = 1;
    } else {
        print "[ --- ] feature $def - DSABLED" if $verbose;
    }
    if ($desc) {
        print " - $desc" if $verbose;
    }
    print " - req v$reqver or higher; have v$c->{modversion}\n" if $verbose;
    
    return $enable ? $def : undef;
}

sub vercmp {
    my ($ay, $be) = map { join('', map { $_ * 100 } split(/\./, $_)) } @_;
    if ($ay > $be) {
        return 1;
    }
    return undef;
}

sub write_ver_file {
    my ($lsv) = @_;
    $lsv //= '1.0.8';
    my ($major, $minor, $revision) = split(/\./, $lsv);
    my $dist_path = dirname(abs_path(__FILE__));
    if (-d "$dist_path/lib/Crypt/Sodium") {
        # we're in the right place.
        open my $fh, '>', "$dist_path/lib/Crypt/Sodium/BuildVersion.pm";
        print $fh "package Crypt::Sodium::BuildVersion;\n";
        print $fh 'our $VERSION = ' . "'v$lsv';\n";
        print $fh 'our $MAJOR = ' . $major . ";\n";
        print $fh 'our $MINOR = ' . $minor . ";\n";
        print $fh 'our $REVISION = ' . $revision . ";\n";
        print $fh "1;\n";
        close $fh;
    }
}
