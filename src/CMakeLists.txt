set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
configure_file (${CMAKE_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Objects/Album.vala
    Objects/Picture.vala
    Objects/MobilePhone.vala
    Objects/ExternalDevice.vala
    Objects/GphotoDevice.vala
    Objects/RemovableDevice.vala
    Widgets/Album.vala
    Widgets/Picture.vala
    Widgets/NavigationBar.vala
    Widgets/NavigationDate.vala
    Widgets/NavigationAlbum.vala
    Widgets/NavigationLabel.vala
    Widgets/NavigationNotFound.vala
    Widgets/NavigationExternalDevice.vala
    Widgets/DuplicateRow.vala
    Widgets/Views/AlbumsView.vala
    Widgets/Views/AlbumView.vala
    Widgets/Views/Welcome.vala
    Widgets/Views/PictureView.vala
    Widgets/Views/PictureDetails.vala
    Widgets/Views/DuplicatesView.vala
    Widgets/Views/NotFoundView.vala
    Services/DataBaseManager.vala
    Services/LocalFilesManager.vala
    Services/LibraryManager.vala
    Services/DeviceManager.vala
    Utils/Utils.vala
    Utils/Pixbuf.vala
    Utils/Exiv2.vala
    Utils/UI.vala
    Dialogs/Preferences.vala
    Dialogs/AlbumEditor.vala
    Popovers/Rename.vala
    Settings.vala
    FastViewWindow.vala
    MainWindow.vala
    Application.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/libraw.vapi
PACKAGES
    granite
    gtk+-3.0
    sqlite3
    gexiv2
    webkit2gtk-4.0
OPTIONS
    --target-glib=2.32
    --thread
)

add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})
target_link_libraries (${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_FULL_BINDIR})
