class Asterisk < Formula
  desc "Open Source PBX and telephony toolkit"
  homepage "http://www.asterisk.org"
  url "https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-18.9.0.tar.gz"
  sha256 "6db6d295d5b99318a68a6c36e797c3a784e921670945acc7202542317ebffaef"

  option "with-dev-mode", "Enable dev mode in Asterisk"
  option "with-clang", "Compile with clang (default)"
  option "with-gcc", "Compile with gcc instead of clang"
  option "without-optimizations", "Disable optimizations"

  option "without-sounds-en", "Install English sound packages"
  option "with-sounds-en-au", "Install Australian sound packages"
  option "with-sounds-en-gb", "Install British sound packages"
  option "with-sounds-es", "Install Spanish sound packages"
  option "with-sounds-fr", "Install French sound packages"
  option "with-sounds-it", "Install Italian sound packages"
  option "with-sounds-ru", "Install Russian sound packages"
  option "with-sounds-ja", "Install Japanese sound packages"
  option "with-sounds-sv", "Install Swedish sound packages"

  option "without-sounds-gsm", "Install GSM formatted sounds"
  option "with-sounds-wav", "Install WAV formatted sounds"
  option "with-sounds-ulaw", "Install uLaw formatted sounds"
  option "with-sounds-alaw", "Install aLaw formatted sounds"
  option "with-sounds-g729", "Install G.729 formatted sounds"
  option "with-sounds-g722", "Install G.722 formatted sounds"
  option "with-sounds-sln16", "Install SLN16 formatted sounds"
  option "with-sounds-siren7", "Install SIREN7 formatted sounds"
  option "with-sounds-siren14", "Install SIREN14 formatted sounds"

  option "with-sounds-extras", "Install extra sound packages"

  if build.with? "gcc"
    fails_with :clang do
      build 9999999 # unconditionally switch to a different compiler
      cause "avoiding clang as the compiler"
    end
    # :gcc just matches on apple-gcc42
    fails_with :gcc do
      cause "Apple's GCC 4.2 is too old to build Asterisk reliably"
    end

    depends_on "gcc" => :build
  end

  depends_on "pkg-config" => :build

  depends_on "jansson"
  depends_on "libgsm"
  depends_on "libxml2"
  depends_on "openssl"
  depends_on "pjsip-asterisk"
  depends_on "speex"
  depends_on "sqlite"
  depends_on "srtp"

  def install
    langs = %w[en en-au en-gb es fr it ru ja sv].select do |lang|
      build.with? "sounds-#{lang}"
    end
    formats = %w[gsm wav ulaw alaw g729 g722 sln16 siren7 siren14].select do |format|
      build.with? "sounds-#{format}"
    end

    dev_mode = false
    optimize = true
    if build.with? "dev-mode"
      dev_mode = true
      optimize = false
    end

    optimize = false if build.without? "optimizations"

    # Some Asterisk code doesn't follow strict aliasing rules
    ENV.append "CFLAGS", "-fno-strict-aliasing"

    system "./configure", "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--localstatedir=#{var}",
                          "--datadir=#{share}/#{name}",
                          "--docdir=#{doc}/asterisk",
                          "--enable-dev-mode=#{dev_mode ? "yes" : "no"}",
                          # "--with-crypto",
                          # "--with-ssl",
                          "--with-pjproject-bundled",
                          # "--with-pjproject",
                          # "--with-sqlite3",
                          # "--without-sqlite",
                          # "--without-gmime",
                          # "--without-gtk2",
                          # "--without-iodbc",
                          # "--without-netsnmp",
                          "--with-resample",
                          "--with-jansson-bundled"

    system "make", "menuselect/cmenuselect",
                   "menuselect/nmenuselect",
                   "menuselect/gmenuselect",
                   "menuselect/menuselect",
                   "menuselect-tree",
                   "menuselect.makeopts"

    # Inline function cause errors with Homebrew's gcc-4.8
    system "menuselect/menuselect",
           "--enable", "DISABLE_INLINE", "menuselect.makeopts"
    # Native compilation doesn't work with Homebrew's gcc-4.8
    system "menuselect/menuselect",
           "--disable", "BUILD_NATIVE", "menuselect.makeopts"

    unless optimize
      system "menuselect/menuselect",
             "--enable", "DONT_OPTIMIZE", "menuselect.makeopts"
    end

    if dev_mode
      system "menuselect/menuselect",
             "--enable", "TEST_FRAMEWORK", "menuselect.makeopts"
      system "menuselect/menuselect",
             "--enable", "DO_CRASH", "menuselect.makeopts"
      system "menuselect/menuselect",
             "--enable-category", "MENUSELECT_TESTS", "menuselect.makeopts"
    end

    formats.each do |format|
      system "menuselect/menuselect",
             "--enable", "MOH-OPSOUND-#{format.upcase}", "menuselect.makeopts"

      langs.each do |lang|
        system "menuselect/menuselect",
               "--enable", "CORE-SOUNDS-#{lang.upcase}-#{format.upcase}", "menuselect.makeopts"

        if build.with? "sounds-extras"
          system "menuselect/menuselect",
                 "--enable", "EXTRA-SOUNDS-#{lang.upcase}-#{format.upcase}", "menuselect.makeopts"
        end
      end
    end

    system "make", "all", "NOISY_BUILD=yes"
    system "make", "install", "samples"

    # Replace Cellar references to opt/asterisk
    system "sed", "-i", "", "s#Cellar/asterisk/[^/]*/#opt/asterisk/#", "#{etc}/asterisk/asterisk.conf"
  end

  plist_options :startup => false, :manual => "asterisk -r"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <dict>
          <key>SuccessfulExit</key>
          <false/>
        </dict>
        <key>Label</key>
          <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_sbin}/asterisk</string>
          <string>-f</string>
          <string>-C</string>
          <string>#{etc}/asterisk/asterisk.conf</string>
        </array>
         <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/asterisk.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/asterisk.log</string>
        <key>ServiceDescription</key>
        <string>Asterisk PBX</string>
      </dict>
    </plist>
    EOS
  end
end
