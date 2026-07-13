require 'xcodeproj'

project_path = 'Podify.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.first

def sync_group(project, target, group, dir_path)
  Dir.entries(dir_path).each do |entry|
    next if entry == '.' || entry == '..' || entry == '.DS_Store'
    full_path = File.join(dir_path, entry)
    
    if File.directory?(full_path)
      # Skip standard Xcode folders
      next if entry.end_with?('.xcassets') || entry.end_with?('.lproj') || entry.end_with?('.xcodeproj') || entry == '.git' || entry == 'Podify.xcodeproj'
      
      subgroup = group.children.find { |c| c.name == entry || c.path == entry }
      subgroup ||= group.new_group(entry, entry)
      sync_group(project, target, subgroup, full_path)
    elsif full_path.end_with?('.swift')
      existing_ref = group.children.find { |c| c.path == entry || c.name == entry }
      unless existing_ref
        file_ref = group.new_reference(full_path)
        target.add_file_references([file_ref])
      end
    end
  end
end

main_group = project.main_group.children.find { |c| c.name == 'Podify' || c.path == 'Podify' }
sync_group(project, main_target, main_group, 'Podify')

# Clean up ContentView.swift from project
content_view = main_group.children.find { |c| c.path == 'ContentView.swift' || c.name == 'ContentView.swift' }
if content_view
  content_view.remove_from_project
end

project.save
puts "Successfully synced Xcode project."
