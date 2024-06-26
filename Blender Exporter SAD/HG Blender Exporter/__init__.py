import importlib
import os
import re
import subprocess
import sys

bl_info = {
    "name": "Haemimont Games Exporter for Stranded - Alien Dawn",
    "author": "Haemimont Games",
    "blender": (2, 93, 0),
    "category": "Import-Export",
    "version": (2, 10),
    "location": "3D View > HGE Tools",
    "description": "HGE Materials, Meshes, Animations, Entities, States",
}

SETTINGS = {
    "version": bl_info["version"],
    "game": "Bacon",
    "appid": "Stranded - Alien Dawn",
    "mtl_prop_0_visible": "False",
    "mtl_prop_0_name": "",
    "enable_colliders": "False",
}

def register():
    """
    Register the Blender Exporter addon.

    This function sets up the necessary paths and imports the required modules.
    It also updates the settings for the Blender Exporter addon.

    Returns:
        None
    """
    script_path = os.getenv('HGETrunkRoot')
    if script_path:
        script_path = os.path.join(script_path, "Tools", "BlenderExport")

    registry_key = "HKEY_CURRENT_USER\\SOFTWARE\\Haemimont Games\\Stranded - Alien Dawn"
    registry_cmd = f"reg query \"{registry_key}\" /v Path"
    registry_result = subprocess.check_output(registry_cmd, stderr=subprocess.STDOUT).decode("ascii")
    registry_result = re.search(r"REG_SZ\s*(.*)\\", registry_result)
    reg_check = re.search(r"Bin\s*(.*)\\", registry_result.group(1))
    if not reg_check:
        script_path = os.path.join(registry_result.group(1), "ModTools")

    print(f"[HG] Loading implementation from '{script_path}'")
    script_path = os.path.normpath(script_path)
    sys.path.insert(0, script_path)

    import BlenderExport
    importlib.reload(BlenderExport)
    for k,v in SETTINGS.items():
        BlenderExport.SETTINGS[k] = v
    BlenderExport.register()

def unregister():
    import BlenderExport
    BlenderExport.unregister()
