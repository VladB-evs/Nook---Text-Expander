import SwiftUI

/// Sidebar organizing the library (All, Favorites), Folders, and Preferences.
/// Themed in #151514 background with #EDA101 accents.
struct SidebarView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var folderToRename: SnippetFolder?
    @State private var renameFolderName = ""
    @State private var folderToDelete: SnippetFolder?

    var body: some View {
        @Bindable var dependencies = dependencies

        List(selection: $dependencies.navigationSelection) {
            if !dependencies.permissions.accessibilityGranted {
                permissionsWarningBanner
            }

            Section("Library") {
                NavigationLink(value: NavigationItem.allSnippets) {
                    Label {
                        Text("All Snippets")
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "tray.full.fill")
                            .foregroundStyle(Color.nookAccent)
                    }
                    .badge(dependencies.snippetStore.snippets.count)
                }

                NavigationLink(value: NavigationItem.favorites) {
                    Label {
                        Text("Favorites")
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.nookAccent)
                    }
                    .badge(dependencies.snippetStore.snippets.filter(\.isFavorite).count)
                }
            }

            Section {
                ForEach(dependencies.snippetStore.folders.sorted(by: { $0.sortOrder < $1.sortOrder })) { folder in
                    NavigationLink(value: NavigationItem.folder(folder.id)) {
                        Label {
                            Text(folder.name)
                                .foregroundStyle(.white)
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.nookSecondaryText)
                        }
                        .badge(dependencies.snippetStore.snippets.filter { $0.folderID == folder.id }.count)
                    }
                    .contextMenu {
                        Button("Rename Folder…") {
                            folderToRename = folder
                            renameFolderName = folder.name
                        }
                        Divider()
                        Button("Delete Folder", role: .destructive) {
                            folderToDelete = folder
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Folders")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nookSecondaryText)
                    Spacer()
                    Button {
                        newFolderName = ""
                        isCreatingFolder = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(Color.nookAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Create New Folder")
                }
            }

            Section("System") {
                NavigationLink(value: NavigationItem.variables) {
                    Label {
                        Text("Variables")
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "curlybraces")
                            .foregroundStyle(Color.nookAccent)
                    }
                    .badge(dependencies.settingsStore.settings.customVariables.count)
                }

                NavigationLink(value: NavigationItem.settings(dependencies.selectedSettingsTab)) {
                    HStack {
                        Label {
                            Text("Settings")
                                .foregroundStyle(.white)
                        } icon: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(Color.nookSecondaryText)
                        }
                        Spacer()
                        if !dependencies.permissions.accessibilityGranted {
                            Circle()
                                .fill(Color.nookAccent)
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                NavigationLink(value: NavigationItem.about) {
                    Label {
                        Text("About")
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.nookSecondaryText)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.nookBackground)
        .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 240)
        .alert("New Folder", isPresented: $isCreatingFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let folder = dependencies.snippetStore.addFolder(named: trimmed)
                    dependencies.navigationSelection = .folder(folder.id)
                }
            }
        }
        .alert("Rename Folder", isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField("Folder Name", text: $renameFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let folder = folderToRename {
                    let trimmed = renameFolderName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        dependencies.snippetStore.renameFolder(folder.id, to: trimmed)
                    }
                }
            }
        }
        .alert("Delete Folder", isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    dependencies.snippetStore.deleteFolder(folder.id)
                    if dependencies.navigationSelection == .folder(folder.id) {
                        dependencies.navigationSelection = .allSnippets
                    }
                }
            }
        } message: {
            Text("Snippets in this folder will remain in All Snippets.")
        }
    }

    private var permissionsWarningBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.nookAccent)
                Text("Permission Needed")
                    .font(.caption.bold())
                    .foregroundStyle(Color.nookAccent)
            }
            Text("Nook requires Accessibility to expand snippets.")
                .font(.caption2)
                .foregroundStyle(Color.nookSecondaryText)
            Button("Grant Access") {
                dependencies.selectedSettingsTab = .permissions
                dependencies.navigationSelection = .settings(.permissions)
                dependencies.permissions.requestAccessibility()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.nookAccent)
            .foregroundStyle(Color.nookBackground)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nookAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 8, trailing: 10))
    }
}
