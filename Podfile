# Lecteur vidéo VLC officiel pour tvOS (lit les flux .ts, .mkv, .avi…)
platform :tvos, '17.0'
use_frameworks!

target 'IPTVPerso' do
  pod 'TVVLCKit', '~> 3.6'
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['TVOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
