Pod::Spec.new do |s|
  s.name             = 'wakelock'
  s.version          = '0.0.1'
  s.summary          = 'Keep screen on'
  s.description      = 'Flutter plugin to prevent screen from sleeping (Android/iOS).'
  s.homepage         = 'https://github.com/example/wakelock'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Author' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
