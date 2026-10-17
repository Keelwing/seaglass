// The home screen type of an open folder, below its folder shapes (LauncherFolder.qml). The Patchmanager hook loads
// this into a Loader under the shape grid; the Loader is its parent and provides folder, the LauncherFolderItem. The
// choice goes to FolderTypes.qml, where HomeController.qml picks it up; finished() closes the shape selector, as a tap
// on a shape does.
import QtQuick 2.6

FolderTypeSelector {
    id: chooser

    readonly property QtObject folder: parent && parent.folder !== undefined ? parent.folder : null
    property QtObject store: FolderTypes {}

    signal finished()

    current: folder ? store.typeOf(folder.title) : "icon"
    onChosen: {
        if (folder)
            store.setType(folder.title, type)
        finished()
    }
}
