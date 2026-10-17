// A widget folder's group widget in its app grid delegate (LauncherGrid.qml). The Patchmanager hook loads this into a
// Loader filling the delegate, in place of the folder icon and its name; the Loader is the parent and provides:
//   folder      the LauncherFolderItem
//   controller  HomeController.qml (types, launching, opening)
//   editMode    the launcher's edit mode
//   dropTarget  an app is held over the tile: dropping it adds it to the folder
//   lifted      the tile is being dragged
// When this file fails to load, the hook shows the folder icon in the widget's block.
import QtQuick 2.6
import org.nemomobile.lipstick 0.1

GroupWidget {
    id: tile

    readonly property Item host: parent
    readonly property Item controller: host && host.controller !== undefined ? host.controller : null

    // only a folder: a model move can hand the delegate an app for a moment, before the layout follows
    folder: host && host.folder && host.folder.type === LauncherModel.Folder ? host.folder : null
    type: controller ? controller.typeOf(folder) : "card"
    editMode: host ? !!host.editMode : false
    dropTarget: host ? !!host.dropTarget : false
    lifted: host ? !!host.lifted : false
    glassSource: controller && controller.glass !== undefined ? controller.glass : null

    onLaunch: controller.launch(item)
    onOpen: controller.open(folder)
    onResize: controller.setType(folder, type)
    onHold: controller.enterEditMode()
}
