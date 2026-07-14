require 'xcodeproj'
project_path = 'Podify.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.resources_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path == 'PodifyInfo.plist'
    puts "Removing PodifyInfo.plist from resources build phase"
    target.resources_build_phase.remove_build_file(build_file)
  end
end

project.save
