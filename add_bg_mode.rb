require 'xcodeproj'

project_path = '/Volumes/vex/VSCode/Podify/Podify.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'Podify/Info.plist'
end

project.save
puts "Successfully linked Info.plist to target #{target.name}"
