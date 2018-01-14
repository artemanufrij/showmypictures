set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
configure_file (${CMAKE_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Objects/Album.vala
    Objects/Picture.vala
    Widgets/Album.vala
    Widgets/Picture.vala
    Widgets/NavigationBar.vala
    Widgets/NavigationDate.vala
    Widgets/NavigationAlbum.vala
    Widgets/NavigationNotFound.vala
    Widgets/DuplicateRow.vala
    Widgets/Views/AlbumsView.vala
    Widgets/Views/AlbumView.vala
    Widgets/Views/Welcome.vala
    Widgets/Views/PictureView.vala
    Widgets/Views/DuplicatesView.vala
    Widgets/Views/NotFoundView.vala
    Services/DataBaseManager.vala
    Services/LocalFilesManager.vala
    Services/LibraryManager.vala
    Utils/Utils.vala
    Utils/Pixbuf.vala
    Dialogs/Preferences.vala
    Dialogs/AlbumEditor.vala
    Settings.vala
    MainWindow.vala
    Application.vala
PACKAGES
    granite
    gtk+-3.0
    sqlite3
    libexif
#    gexiv2
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --target-glib=2.32
    --thread
)

add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})
target_link_libraries (${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_FULL_BINDIR})
