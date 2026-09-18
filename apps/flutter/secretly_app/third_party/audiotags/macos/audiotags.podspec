# Download the binary from GitHub.
version = "1.4.5"
lib_url = "https://github.com/erikas-taroza/audiotags/releases/download/v#{version}/macos.zip"

`
mkdir -p Libs
cd Libs
if [ ! -f macos.zip ]
then
  curl -L "#{lib_url}" -o macos.zip
  unzip macos.zip
  rm macos.zip
fi
cd ..
`

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_libraries = 'Libs/libaudiotags.a'
  s.dependency 'FlutterMacOS'
  s.dependency 'rust_lib_audiotags'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load ${PODS_TARGET_SRCROOT}/Libs/libaudiotags.a',
  }
  s.swift_version = '5.0'
end
