require 'xcodeproj'
project = Xcodeproj::Project.open('Podify.xcodeproj')
target = project.targets.first

phase = target.shell_script_build_phases.find { |p| p.name == 'Add Background Modes' }
unless phase
  phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  phase.name = 'Add Background Modes'
  phase.shell_script = %Q{
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$TARGET_BUILD_DIR/$INFOPLIST_PATH" || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string audio" "$TARGET_BUILD_DIR/$INFOPLIST_PATH" || true
  }
  target.build_phases << phase
end
project.save
puts "Added build phase for UIBackgroundModes"
