# ---
# This code imports several Python modules that are commonly used in Blender development:
# 
# - `os`: Provides a way to interact with the operating system, including file and directory operations.
# - `re`: Provides regular expression matching operations.
# - `subprocess`: Allows you to spawn new processes, connect to their input/output/error pipes, and obtain their return codes.
# - `threading`: Provides a way to create and manage threads, which can be useful for running tasks concurrently.
# - `bpy`: The Blender Python API, which provides access to Blender's data, tools, and functionality.
# - `bpy_extras`: Additional utility functions for the Blender Python API.
# 
# These imports are likely used throughout the rest of the Blender Exporter JA3 project to provide functionality for tasks such as file management, data processing, and integration with the Blender application.
import os
import re
import subprocess
import threading
import bpy
import bpy_extras

# settings--------------------------------------------------------------------------------------------------------------------------------------------------------
#The selected code defines a set of global variables that store various settings for the Blender Exporter JA3 project.
#
#`CM_VERSION`: A string that represents the version of the Blender Exporter JA3 project.
#
#`SETTINGS`: A dictionary that stores various settings for the Blender Exporter JA3 project, including:
#- `version`: The version of the game or application being exported.
#- `game`: The name of the game or application being exported.
#- `appid`: The ID of the game or application being exported.
#- `mtl_prop_0_visible`: A setting that controls the visibility of a material property.
#- `mtl_prop_0_name`: The name of a material property.
#- `enable_colliders`: A setting that controls whether colliders are enabled in the exported data.
CM_VERSION = "71"
SETTINGS = {
    "version": "",
    "game": "",
    "appid": "",
    "mtl_prop_0_visible": "",
    "mtl_prop_0_name": "",
    "enable_colliders": "",
}

# common--------------------------------------------------------------------------------------------------------------------------------------------------------

#This class represents an entity name in the Blender Exporter JA3 project. It contains information about the entity, such as its name, mesh, level of detail (LOD), LOD distance, state, comment, and inheritance.
#
#The `parse` method takes a full name string and extracts the relevant information, creating a new `EntityName` instance. The `__str__` method returns a string representation of the entity name in the expected format.
class EntityName:
This class represents an entity name in the Blender Exporter JA3 project. It contains information about the entity, such as its name, mesh, level of detail (LOD), LOD distance, state, comment, and inheritance.
    
    The `parse` method takes a full name string and extracts the relevant information, creating a new `EntityName` instance. The `__str__` method returns a string representation of the entity name in the expected format.
        name: str
    mesh: str
    lod: int
    lod_distance: int
    state: str
    comment: str
    inherit: str
#    hge_export: bool

    @staticmethod
    def parse(full_name):
        tokens = full_name.split(":")
        if len(tokens) < 5 or tokens[0] != "hgm":
            return None
        res = EntityName()
        res.name = tokens[1]
        res.mesh = tokens[2]
        res.lod = int(tokens[3])
        res.lod_distance = int(tokens[4])
        res.state = None
        res.inherit = None
        for token in tokens[5:]:
            if "s=" in token:
                res.state = token[2:]
            elif "i=" in token:
                res.inherit = token[2:]
            else:
                res.comment = None
                if not res.state:
                    res.comment = token
        return res

    def __str__(self):
        pieces = [
            "hgm",
            self.name,
            self.mesh,
            self.lod,
            self.lod_distance,
        ]
        if self.state:
            pieces.append(f"s={self.state}")
        if self.inherit != "None":
            pieces.append(f"i={self.inherit} mesh")
        if self.comment:
            pieces.append(f"{self.comment}")
        return ":".join(pieces)


#---
#--- Represents the name of an animation in the Blender exporter.
#---
#--- The `AnimationName` class is used to parse and represent the name of an animation in the Blender exporter. The name is expected to be in a specific format, with the following components:
#---
#--- - `entity`: The name of the entity that the animation is associated with.
#--- - `state`: The state of the entity that the animation is associated with.
#--- - `mesh`: The name of the mesh that the animation is associated with.
#---
#--- The `parse` method takes a full name string in the expected format and extracts the relevant information, creating a new `AnimationName` instance. The `__str__` method returns a string representation of the animation name in the expected format.
#---
#--- The `get_export_name` method returns the export name for the animation, which is the same as the string representation but with "hga" replaced by "hgx".
class AnimationName:
    entity: str
    state: str
    mesh: str

    @staticmethod
    def parse(full_name):
        tokens = full_name.split(":")
        if len(tokens) < 4 or tokens[0] != "hga":
            return None
        res = AnimationName()
        res.entity = tokens[1]
        res.state = tokens[2]
        res.mesh = tokens[3]
        return res

    def __str__(self):
        return ":".join([
            "hga",
            self.entity,
            self.state,
            self.mesh,
        ])

    def get_export_name(self):
        return str(self).replace("hga", "hgx", 1)


#---
#--- Checks if the given object has the specified property.
#---
#--- @param object table The object to check.
#--- @param prop string The property to check.
#--- @return boolean True if the object has the specified property, false otherwise.
#---
def prop_exists(object, prop):
    return prop in {
        *object.keys(),
        *type(object).bl_rna.properties.keys(),
    }


#---
#--- Checks if the given name starts with a hyphen and has a length greater than 2.
#---
#--- @param name string The name to check.
#--- @return boolean True if the name starts with a hyphen and has a length greater than 2, false otherwise.
#---
def is_attach(name):
    return len(name) > 2 and name.startswith("-")


#---
#--- Finds all the states associated with the given entity in the current scene.
#---
#--- @param entity string The entity to find states for.
#--- @param context table (optional) The Blender context to use. If not provided, the current context will be used.
#--- @param ignore_obj table (optional) An object to ignore when finding states.
#--- @param static boolean (optional) Whether to include static mesh objects. Defaults to true.
#--- @param animated boolean (optional) Whether to include animated objects. Defaults to true.
#--- @return table A set of all the states associated with the given entity.
#---
def find_states(entity, context=None, ignore_obj=None, static=True, animated=True):
    if not context:
        context = bpy.context
    states = set()
    for object in context.scene.objects:
        if object == ignore_obj:
            continue
        if object.type == "MESH" and static:
            hge_obj_settings = object.hge_obj_settings
            if hge_obj_settings.resolve_role() != "MESH":
                continue
            if hge_obj_settings.entity != entity:
                continue
            if hge_obj_settings.state:
                states.add(hge_obj_settings.state)
        elif object.type == "ARMATURE" and animated:
            for prop in object.keys():
                anim_name = AnimationName.parse(prop)
                if not anim_name:
                    continue
                states.add(anim_name.state)
    return states

#---
#--- A list of property names that represent surface collider flags.
#---
#--- @field surface_collider_flag_T string The property name for the "T" surface collider flag.
#--- @field surface_collider_flag_P string The property name for the "P" surface collider flag.
#--- @field surface_collider_flag_V string The property name for the "V" surface collider flag.
#--- @field surface_collider_flag_S string The property name for the "S" surface collider flag.
#--- @field surface_collider_flag_A string The property name for the "A" surface collider flag.
#--- @field surface_collider_flag_I string The property name for the "I" surface collider flag.
#---
surface_collider_flag_props = [
    "surface_collider_flag_T",
    "surface_collider_flag_P",
    "surface_collider_flag_V",
    "surface_collider_flag_S",
    "surface_collider_flag_A",
    "surface_collider_flag_I",
]
#---
#--- Updates the surface collider flags for the given HGEObjectSettings.
#--- If none of the surface collider flag properties are set, this function will set the 'P', 'V', and 'S' flags to true.
#---
#--- @param settings HGEObjectSettings The HGEObjectSettings to update the surface collider flags for.
#--- @param context table The Blender context.
#---
def update_surf_collider_flags(settings: "HGEObjectSettings", context):
    if not any(getattr(settings, prop) for prop in surface_collider_flag_props):
        settings.surface_collider_flag_P = True
        settings.surface_collider_flag_V = True
        settings.surface_collider_flag_S = True

#---
#--- Updates the animation inheritance settings for the given HGEObjectSettings.
#---
#--- @param settings HGEObjectSettings The HGEObjectSettings to update the animation inheritance for.
#--- @param context table The Blender context.
#---
def update_inherit_animation(settings: "HGEObjectSettings", context):
    if settings.inherit_animation != "None":
        settings.state = "_mesh"
    else:
        settings.state = "idle"

#---
#--- A table that maps game names to a list of animation inheritance options.
#--- Each entry in the table is a tuple with the following fields:
#---   1. The internal name of the animation inheritance option
#---   2. The display name of the animation inheritance option
#---   3. A description of the animation inheritance option
#---   4. An integer index for the animation inheritance option
#---
#--- The keys in this table are the names of the games that the animation inheritance options apply to.
#---
INHERIT_ANIM_ITEMS = {
    "Zulu": (
        ("None", "None", "no inheritance", 0),
        ("Male", "Male animations", "Inherits male torso animations", 1),
        ("Animal_Crocodile", "Animal_Crocodile animations", "Animal_Crocodile animations", 2),
        ("Animal_Hen", "Animal_Hen animations", "Animal_Hen animations", 3),
        ("Animal_Hyena", "Animal_Hyena animations", "Animal_Hyena animations", 4),
    ),
    "Bacon": (
        ("None", "No", "no inheritance", 0),
        ("HumanMale", "Yes", "Inherits human animations", 1),
    ),
}

#---
#--- Callback function for the 'Inherits animation' enum property in the HGEObjectSettings class.
#--- This function is called when the 'inherit_animation' property is updated, and it updates the 'state' property
#--- based on the selected animation inheritance option.
#---
#--- @param self HGEObjectSettings The HGEObjectSettings instance that the property belongs to.
#--- @param context table The Blender context.
#---
def inherit_anim_items_callback(self, context):
    return INHERIT_ANIM_ITEMS.get(SETTINGS["game"], (("None", "None", "no inheritance", 0),))

#---
#--- Represents the settings for an HGE (Haeminton Games Engine) object in the Blender exporter.
#--- This class is a Blender property group that contains various properties related to the export of an object to the HGE format.
#---
#--- The properties in this class include:
#--- - `ignore`: A boolean property that determines whether the object is ignored by the HGE exporter.
#--- - `entity`: A string property that specifies the entity name for the object.
#--- - `inherit_animation`: An enum property that specifies the animation inheritance option for the object.
#--- - `mesh`: A string property that specifies the mesh name for the object.
#--- - `state`: A string property that specifies the state name for the object.
#--- - `lod`: An integer property that specifies the level of detail (LOD) for the object.
#--- - `lod_distance`: An integer property that specifies the LOD distance for the object.
#--- - `surface`: An enum property that specifies the surface type for the object.
#--- - `surface_collider_kind`: An enum property that specifies the collision kind for the object.
#--- - `surface_collider_flag_T`, `surface_collider_flag_P`, `surface_collider_flag_V`, `surface_collider_flag_S`, and `surface_collider_flag_A`: Boolean properties that specify various surface collider flags for the object.
#---
class HGEObjectSettings(bpy.types.PropertyGroup):
    ignore: bpy.props.BoolProperty(
        name="Ignore",
        description="Whether or not the object is ignored by the HG exporter entirely",
        default=False)
    entity: bpy.props.StringProperty(
        name="Entity name")
    inherit_animation: bpy.props.EnumProperty(
        name="Inherits animation",
        items=inherit_anim_items_callback,
        default=0, update=update_inherit_animation)
    mesh: bpy.props.StringProperty(
        name="Mesh name")
    state: bpy.props.StringProperty(
        name="State name",
        default="idle")
    lod: bpy.props.IntProperty(
        name="LOD",
        min=1,
        max=5,
        default=1)
    lod_distance: bpy.props.IntProperty(
        name="LOD Distance",
        min=0,
        default=0)
    surface: bpy.props.EnumProperty(
        name="Surface type",
        items=[
            ("Collision", "Collision", ""),
            ("Walk", "Walk", ""),
            ("BlockPass", "Block passability", ""),
            ("Height", "Height", ""),
            ("HexShape", "Hex shape", ""),
            ("Build", "Build", ""),
            ("Selection", "Selection", ""),
            ("TerrainHole", "Terrain hole", ""),
            ("Terrain", "Terrain", ""),
        ], default="Collision")
    surface_collider_kind: bpy.props.EnumProperty(
        name="Collision kind",
        items=[
            ("CollisionBox", "Box", ""),
            ("CollisionSphere", "Sphere", ""),
            ("CollisionCapsule", "Capsule", ""),
            ("Collision", "Mesh", ""),
        ], default="Collision")
    surface_collider_flag_T: bpy.props.BoolProperty(name="Terrain", default=False, update=update_surf_collider_flags)
    surface_collider_flag_P: bpy.props.BoolProperty(name="Passability", default=True, update=update_surf_collider_flags)
    surface_collider_flag_V: bpy.props.BoolProperty(name="Visibility", default=True, update=update_surf_collider_flags)
    surface_collider_flag_S: bpy.props.BoolProperty(name="Obstruction", default=True, update=update_surf_collider_flags)
    surface_collider_flag_A: bpy.props.BoolProperty(name="Action Camera", default=False, update=update_surf_collider_flags)
    surface_collider_flag_I: bpy.props.BoolProperty(name="Interaction", default=False, update=update_surf_collider_flags)
    spot_name: bpy.props.StringProperty(
        name="Spot name")
    spot_annotation: bpy.props.StringProperty(
        name="Annotation")

    def find_parent_with_role(self, role):
        parent = self.id_data.parent
        if parent and parent.hge_obj_settings.resolve_role() == role:
            return parent

    def resolve_role(self):
        object = self.id_data
        if self.ignore == True:
            return "IGNORED"
        if object.type == "EMPTY":
            if not object.parent:
                return "ORIGIN"
            else:
                if self.find_parent_with_role("MESH") or object.parent_bone:
                    return "SPOT"
        elif object.type == "CURVE":
            if self.find_parent_with_role("MESH") or object.parent_bone:
                return "SPOT"
        elif object.type == "ARMATURE":
            if not object.parent:
                return "ORIGIN"
            else:
                return "ARMATURE"
        elif object.type == "MESH":
            if self.find_parent_with_role("MESH"):
                return "SURFACE"
            elif self.find_parent_with_role("ORIGIN"):
                return "MESH"
            elif self.find_parent_with_role("ARMATURE"):
                return "MESH"
        else:
            print(f"didn't resolved role for {object.type}")
            return object.type

    def find_origin(self):
        return self.find_parent_with_role("ORIGIN")

    def is_skinned(self):
        return self.id_data.vertex_groups

    def is_spot_path(self):
        return self.resolve_role() == "SPOT" and self.id_data.type == "CURVE"
    
    def get_ignored(self):
        ignored = []
        object = self.id_data
        role = self.resolve_role()
        if role == "IGNORED":
            ignored.append(f"{object.name} is ignored")
        return ignored

    def get_errors(self):
        errors = []
        object = self.id_data
        role = self.resolve_role()
        if role in {"SPOT", "SURFACE"}:
            mesh = self.find_parent_with_role("MESH")
            if not mesh and not object.parent_bone:
                errors.append("There is no parent mesh object")
            elif not mesh.hge_obj_settings.is_valid():
                errors.append("The mesh object has errors")
            if role == "SPOT":
                if not self.spot_name:
                    errors.append("Spot name is empty")
                elif not re.match(r"^[a-zA-Z0-9_-]+$", self.spot_name):
                    errors.append("Spot name contains illegal characters")
            elif role == "SURFACE":
                if mesh:
                    for child in mesh.children:
                        if child.hge_obj_settings == self:
                            continue
                        if child.hge_obj_settings.resolve_role() != "SURFACE":
                            continue
                        if child.hge_obj_settings.surface == self.surface:
                            if not SETTINGS["enable_colliders"] or self.surface != "Collision":
                                errors.append("Multiple surfaces of the same type")
                                break
        elif role == "MESH":
            origin = self.find_origin()
            if not origin:
                errors.append("There's no origin object")
            else:
                for other_object in bpy.context.scene.objects:
                    if (other_object != self and
                    other_object.type == "MESH" and
                    other_object.hge_obj_settings.entity == self.entity and
                    other_object.hge_obj_settings.mesh == self.mesh):
                        other_origin = other_object.hge_obj_settings.find_origin()
                        if other_origin != origin:
                            errors.append("Multiple origins for the same mesh")
                            break
            if not self.entity:
                errors.append("Entity name is empty")
            elif not re.match(r"^[a-zA-Z0-9_]+$", self.entity):
                errors.append("Entity name contains illegal characters")
            if not self.mesh:
                errors.append("Mesh name is empty")
            if not self.state:
                errors.append("State name is empty")
            else:
                if self.entity:
                    if self.state in find_states(self.entity, ignore_obj=self.id_data, animated=False) and self.lod == 1:
                        errors.append("State name is not unique")
                    if self.is_skinned():
                        has_animation = False
                        for object in bpy.context.scene.objects:
                            if object.type != "ARMATURE":
                                continue
                            for prop in object.keys():
                                anim_name = AnimationName.parse(prop)
                                if not anim_name:
                                    continue
                                if anim_name.state == self.state:
                                    has_animation = True
                                    break
                        if not has_animation and self.inherit_animation == "None":
                            errors.append("State of skinned mesh is not animated")
            if self.lod == 1 and self.lod_distance > 0:
                errors.append("LOD distance for LOD 1 must be 0")
            if self.lod > 1 and self.lod_distance < 1:
                errors.append("Distance should be more than 0")
        hge_name = self.get_hge_name()
        if hge_name and len(hge_name) > 55:
            errors.append("The combined length of all names is too long")
        return errors

    def is_valid(self):
        return not self.get_errors()

    def get_mesh_name_helper(self, comment=None):
        entity_name = EntityName()
        entity_name.name = self.entity
        entity_name.mesh = self.mesh
        entity_name.lod = str(self.lod)
        entity_name.lod_distance = str(self.lod_distance)
        entity_name.state = self.state
        entity_name.inherit = self.inherit_animation
        entity_name.comment = comment
#        entity_name.hge_export = self.id_data.hge_export
        return entity_name

    def get_hge_name(self, comment=None):
        role = self.resolve_role()
        if role == "SPOT":
            return self.get_spot_name(comment)
        elif role == "SURFACE":
            return self.get_surface_name(comment)
        elif role == "MESH":
            entity_name = self.get_mesh_name_helper(comment)
            return str(entity_name)

    def get_spot_name(self, comment=None):
        name = self.spot_name
        if not name:
            return
        if comment:
            name = f"{name}^{comment}"
        if self.spot_annotation and not self.is_spot_path():
            return f"-{name};{self.spot_annotation}"
        else:
            return f"-{name}"

    def get_surface_name(self, comment=None):
        name = self.surface
        if self.surface == "Collision" and SETTINGS["enable_colliders"]:
            flags = "".join(prop[-1] for prop in surface_collider_flag_props if getattr(self, prop))
            name = f"{self.surface_collider_kind}:{flags}"
        if comment:
            name = f"{name}^{comment}"
        return name

#---
#--- The `HGEObjectSettingsPanelBase` class is the base class for the Blender UI panel that displays settings for HGE (Havok Game Engine) objects in the Blender scene. This panel allows the user to configure various properties of the HGE object, such as the entity name, mesh, LOD, and animation inheritance.
#---
#--- The panel provides a consistent interface for editing HGE object settings across different types of objects (e.g. spots, surfaces, meshes) and handles the logic for displaying the appropriate UI elements based on the object's role.
#---
#--- This class is likely an abstract base class that is extended by more specific UI panel classes for different types of HGE objects.
class HGEObjectSettingsPanelBase:
    def draw_entity_editor(self, context):
        hge_obj_settings = context.object.hge_obj_settings
        self.layout.prop(hge_obj_settings, "entity")
        self.layout.prop(hge_obj_settings, "inherit_animation")
        self.layout.prop(hge_obj_settings, "mesh")
        state_row = self.layout.row()
        state_row.prop(hge_obj_settings, "state")
        state_row.enabled = hge_obj_settings.inherit_animation == "None"
        self.layout.prop(hge_obj_settings, "lod", slider=True)
        self.layout.prop(hge_obj_settings, "lod_distance")

    def draw(self, context):
        if not context.object:
            self.layout.label(text="Here you'll see information about the active object")
        else:
            hge_obj_settings = context.object.hge_obj_settings
            role = hge_obj_settings.resolve_role()
            self.layout.prop(hge_obj_settings, "ignore")
            if role == "ORIGIN":
                self.layout.label(text="This is an origin object")
            elif role == "SPOT":
                is_path = hge_obj_settings.is_spot_path()
                is_animated = context.object.parent_bone
                if is_animated:
                    self.layout.label(text="This is an animated spot")
                else:
                    spot_kind = is_path and "path" or "spot"
                    self.layout.label(text=f"This is a {spot_kind}")
                self.layout.prop(hge_obj_settings, "spot_name")
                if not is_path:
                    self.layout.prop(hge_obj_settings, "spot_annotation")
            elif role == "SURFACE":
                self.layout.label(text="This is a surface")
                self.layout.prop(hge_obj_settings, "surface")
                if hge_obj_settings.surface == "Collision" and SETTINGS["enable_colliders"]:
                    self.layout.prop(hge_obj_settings, "surface_collider_kind")
                    for prop in surface_collider_flag_props:
                        self.layout.prop(hge_obj_settings, prop)
            elif role == "MESH":
                self.layout.label(text="This is a mesh object and can be exported")
                self.draw_entity_editor(context)
            elif context.object.type == "ARMATURE":
                self.layout.label(text="This armature can be used for animations")
            else:
                self.layout.label(text="This object will be ignored during export.")
            if role not in {"IGNORED", "ORIGIN", ""}:
                self.layout.label(text=f"Export name: {hge_obj_settings.get_hge_name()}")
            errors = hge_obj_settings.get_errors()
            if errors:
                self.layout.label(text="To export this object you need to fix these errors:", icon="ERROR")
                for i in range(len(errors)):
                    self.layout.label(text=f"{i+1}) {errors[i]}")


"""
Represents a panel in the Blender UI that displays settings for a Haemimont Game Engine (HGE) object.

This panel is displayed in the object properties window in Blender, and allows the user to configure various settings for the HGE object, such as its mesh, state, level of detail, and other properties.

The panel is implemented as a Blender UI panel, and is registered with the Blender UI system using the `bpy.types.Panel` class.
"""
class HGEObjectSettingsPanel(HGEObjectSettingsPanelBase, bpy.types.Panel):
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "object"
    bl_idname = "HGE_PT_object_settings"
    bl_label = "Haemimont Object"

# materials--------------------------------------------------------------------------------------------------------------------------------------------------------

"""
Represents a definition for a material property that can be assigned to a Blender material.

The `MaterialPropDef` class defines the properties of a material property, including its ID, default value, and the name of the corresponding setting in the material properties.

This class is used to define the set of material properties that can be assigned to Blender materials and exported to the Haemimont Game Engine.
"""
class MaterialPropDef:
    def __init__(self, id, default, settings_name, map=False):
        self.id = id
        self.default = default
        self.settings_name = settings_name
        self.map = map


# these are the properties that will be visible by the AssetsProcessor
# they are assigned as "custom properties" of the materials
#/**
# * Defines a set of material properties that can be assigned to Blender materials and exported to the Haemimont Game Engine.
# *
# * Each `MaterialPropDef` instance represents a single material property, with the following properties:
# * - `id`: A unique identifier for the material property.
# * - `default`: The default value for the material property.
# * - `settings_name`: The name of the corresponding setting in the material properties.
# * - `map`: A boolean indicating whether the material property is a texture map.
# *
# * This list of `MaterialPropDef` instances is used to define the set of material properties that can be configured in the Blender UI and exported to the Haemimont Game Engine.
# */
MATERIAL_PROPERTIES = [
    MaterialPropDef("AlphaTestValue", 0, "alpha_test_value"),
    MaterialPropDef("AlphaBlendMode", 0, "alpha_blend_mode"),
    MaterialPropDef("DepthWrite", 0, "depth_write"),
    MaterialPropDef("ViewDependentOpacity", 0, "view_dependant_opacity"),
    MaterialPropDef("TranslucentShading", 0, "translucent_shading"),
    MaterialPropDef("TwoSidedShading", 0, "two_sided_shading"),
    MaterialPropDef("FoliageNormals", 0, "foliage_normals"),
    MaterialPropDef("NormalMapAsDistortion", 0, "normal_map_as_distortion"),
    MaterialPropDef("SubsurfaceScattering", 0, "subsurface_scattering"),
    MaterialPropDef("Hair", 0, "hair"),
    MaterialPropDef("BlendMaterials", 0, "blend_materials"),
    MaterialPropDef("RoughnessDistanceAdjust", 0, "roughness_distance_adjust"),
    MaterialPropDef("DepthSoftness", 0, "depth_softness"),
    MaterialPropDef("CastShadow", 0, "cast_shadows"),
    MaterialPropDef("ReceiveShadow", 0, "receive_shadows"),
    MaterialPropDef("ShadowBias", 0, "shadow_bias"),
    MaterialPropDef("Special", 0, "special"),
    MaterialPropDef("BaseColorDecal", 0, "base_color_decal"),
    MaterialPropDef("NormalMapDecal", 0, "normal_map_decal"),
    MaterialPropDef("RMDecal", 0, "rm_decal"),
    MaterialPropDef("AODecal", 0, "ao_decal"),
    MaterialPropDef("TriplanarDecal", 0, "triplanar_decal"),
    MaterialPropDef("DoubleSidedDecal", 0, "double_sided_decal"),
    MaterialPropDef("DecalGroup", 0, "decal_group"),
    MaterialPropDef("NoDepthTestable", 0, "no_depth_testable"),
    MaterialPropDef("UIElement", 0, "ui_element"),
    MaterialPropDef("CMColors", 0, "cm_colors"),
    MaterialPropDef("Terrain", 0, "terrain"),
    MaterialPropDef("Deposition", 0, "deposition"),
    MaterialPropDef("TerrainDistortedMesh", 0, "terrain_distorted_mesh"),
    MaterialPropDef("Mirrorable", 0, "mirrorable"),
    MaterialPropDef("VertexNoise", 0, "wrap"),
    MaterialPropDef("VertexColorUsage0", 0, "vertex_color_usage_red"),
    MaterialPropDef("VertexColorUsage1", 0, "vertex_color_usage_green"),
    MaterialPropDef("VertexColorUsage2", 0, "vertex_color_usage_blue"),
    MaterialPropDef("VertexColorUsage3", 0, "vertex_color_usage_alpha"),
    MaterialPropDef("ProjectSpecific0", 0, "project_specific_0"),
    MaterialPropDef("AnimationTime", 0, "animation_time"),
    MaterialPropDef("AnimationFramesX", 0, "animation_frames_x"),
    MaterialPropDef("AnimationFramesY", 0, "animation_frames_y"),
    MaterialPropDef("BaseColorMapFile", "", "base_color", map=True),
    MaterialPropDef("BaseColorMapChannel", 1, None),
    MaterialPropDef("NormalMapFile", "", "normal_map", map=True),
    MaterialPropDef("NormalMapChannel", 1, None),
    MaterialPropDef("RoughnessMetallicMapFile", "", "roughness_metallic_map", map=True),
    MaterialPropDef("RoughnessMetallicMapChannel", 1, None),
    MaterialPropDef("AmbientMapFile", "", "ambient_occlusion_map", map=True),
    MaterialPropDef("AmbientMapChannel", 1, None),
    MaterialPropDef("SelfIllumMapFile", "", "self_illum_map", map=True),
    MaterialPropDef("SelfIllumMapChannel", 1, None),
    MaterialPropDef("ColorizationMaskFile", "", "colorization_mask", map=True),
    MaterialPropDef("ColorizationMaskChannel", 1, None),
    MaterialPropDef("SpecialMapFile", "", "special_map", map=True),
    MaterialPropDef("SpecialMapChannel", 1, None),
    MaterialPropDef("CMVersion", CM_VERSION, None),
]


#---
#Removes all material properties from the given material.
#
#This function is used to clear out any existing material properties before adding new ones. It iterates through the list of known material properties and deletes any that are present on the material.
#
#@param material The material to remove the properties from.
def remove_material_props(material):
    for prop in MATERIAL_PROPERTIES:
        if prop_exists(material, prop.id):
            del material[prop.id]


#---
#Adds the material properties defined in the `MATERIAL_PROPERTIES` list to the given material.
#
#This function is used to set the material properties on a material object. It iterates through the list of known material properties and sets any that are not already present on the material.
#
#@param material The material to add the properties to.
def add_material_props(material):
    for prop in MATERIAL_PROPERTIES:
        if not prop_exists(material, prop.id):
            material[prop.id] = prop.default


#---
#Recreates the shader nodes for the material based on the settings provided.
#
#This function is responsible for setting up the material nodes in the Blender node tree to match the desired material properties. It clears any existing nodes, creates new nodes for the base color, normal map, roughness/metallic map, and links them together to form the final material shader.
#
#The function takes in the material settings object and the Blender context, and updates the material's node tree accordingly.
#
#@param settings The material settings object containing the texture images and other properties.
#@param context The Blender context.
def recreate_shader_nodes(settings, context):
    unused_nodes = []
    material = settings.id_data

    # setup material
    material.use_nodes = True
    material.use_backface_culling = settings.two_sided_shading
    material.blend_method = "OPAQUE"
    material.alpha_threshold = 0
    if settings.alpha_blend_mode == "1":
        if settings.alpha_test_value > 0:
            material.blend_method = "CLIP"
            material.alpha_threshold = settings.alpha_test_value / 255.0
    elif settings.alpha_blend_mode == "2":
        material.blend_method = "BLEND"

    # remove old shader nodes
    node_tree = material.node_tree
    node_tree.nodes.clear()

    # setup new nodes and links
    output = node_tree.nodes.new("ShaderNodeOutputMaterial")
    output.target = "EEVEE"
    output.location = (0, 20)

    bsdf = node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-260, 0)
    bsdf.inputs["Specular"].default_value = 0
    node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"], verify_limits=True)

    base_color = node_tree.nodes.new("ShaderNodeTexImage")
    base_color.location = (-780, 20)
    base_color.image = settings.base_color
    node_tree.links.new(base_color.outputs["Color"], bsdf.inputs["Base Color"], verify_limits=True)
    node_tree.links.new(base_color.outputs["Alpha"], bsdf.inputs["Alpha"], verify_limits=True)

    normal_map = node_tree.nodes.new("ShaderNodeTexImage")
    normal_map.location = (-780, -780)
    normal_map.image = settings.normal_map
    node_tree.links.new(normal_map.outputs["Color"], bsdf.inputs["Normal"], verify_limits=True)

    roughness_metallic_map = node_tree.nodes.new("ShaderNodeTexImage")
    roughness_metallic_map.location = (-780, -240)
    roughness_metallic_map.image = settings.roughness_metallic_map
    separate_rgb = node_tree.nodes.new("ShaderNodeSeparateRGB")
    separate_rgb.location = (-480, -180)
    node_tree.links.new(roughness_metallic_map.outputs["Color"], separate_rgb.inputs["Image"], verify_limits=True)
    node_tree.links.new(separate_rgb.outputs["R"], bsdf.inputs["Roughness"], verify_limits=True)
    if settings.translucent_shading:
        invert = node_tree.nodes.new("ShaderNodeInvert")
        invert.location = (-480, -320)
        node_tree.links.new(separate_rgb.outputs["B"], invert.inputs["Color"], verify_limits=True)
        node_tree.links.new(invert.outputs["Color"], bsdf.inputs["Alpha"], verify_limits=True)
    else:
        node_tree.links.new(separate_rgb.outputs["B"], bsdf.inputs["Metallic"], verify_limits=True)

    ambient_occlusion_map = node_tree.nodes.new("ShaderNodeTexImage")
    ambient_occlusion_map.location = (-780, -260)
    ambient_occlusion_map.image = settings.ambient_occlusion_map
    if settings.ambient_occlusion_map:
        mix_rgb = node_tree.nodes.new("ShaderNodeMixRGB")
        mix_rgb.location = (-480, 0)
        mix_rgb.blend_type = "MULTIPLY"
        mix_rgb.inputs["Fac"].default_value = 1.0
        ambient_occlusion_map.location = (-780, 40)
        base_color.location = (-780, 300)
        node_tree.links.new(base_color.outputs["Color"], mix_rgb.inputs["Color1"], verify_limits=True)
        node_tree.links.new(ambient_occlusion_map.outputs["Color"], mix_rgb.inputs["Color2"], verify_limits=True)
        node_tree.links.new(mix_rgb.outputs["Color"], bsdf.inputs["Base Color"], verify_limits=True)

    self_illum_map = node_tree.nodes.new("ShaderNodeTexImage")
    self_illum_map.location = (-780, -520)
    self_illum_map.image = settings.self_illum_map
    node_tree.links.new(self_illum_map.outputs["Color"], bsdf.inputs["Emission"], verify_limits=True)

    colorization_mask = node_tree.nodes.new("ShaderNodeTexImage")
    colorization_mask.location = (-780, -280)
    colorization_mask.image = settings.colorization_mask

    special_map = node_tree.nodes.new("ShaderNodeTexImage")
    special_map.location = (-780, -300)
    special_map.image = settings.special_map

    # determine unused nodes
    unused_nodes = []
    for node in node_tree.nodes:
        if not node.outputs:
            continue
        is_used = False
        for out in node.outputs:
            if out.is_linked:
                is_used = True
                break
        if not is_used:
            unused_nodes.append(node)

    # animation UV transformation
    if settings.animation_time > 0:
        frames_x = max(1, settings.animation_frames_x)
        frames_y = max(1, settings.animation_frames_y)
        if frames_x > 1 or frames_y > 1:
            uv_map = node_tree.nodes.new("ShaderNodeUVMap")
            uv_map.from_instancer = True
            uv_map.location = (-1200, -520)
            mapping = node_tree.nodes.new("ShaderNodeMapping")
            mapping.vector_type = "VECTOR"
            mapping.location = (-980, -460)
            mapping.inputs["Scale"].default_value = (1.0 / frames_x, 1.0 / frames_y, 1.0)
            node_tree.links.new(uv_map.outputs["UV"], mapping.inputs["Vector"], verify_limits=True)
            for texture_node in node_tree.nodes:
                if isinstance(texture_node, bpy.types.ShaderNodeTexImage) and texture_node not in unused_nodes:
                    node_tree.links.new(mapping.outputs["Vector"], texture_node.inputs["Vector"], verify_limits=True)

    # clear unused nodes
    node_name = 'Image Texture'
    all_tex_nodes = []
    clear_unused_nodes = bpy.context.active_object.active_material.node_tree.nodes
    if unused_nodes:
        unodes_count = len(unused_nodes)
        unodes_rem = 0
        for node in unused_nodes:
            clear_unused_nodes.remove(clear_unused_nodes[node.name])
            unodes_rem += 1
    print(f"{unodes_count - unodes_rem} unused nodes left, {unodes_rem} unused nodes removed\n")
    unused_nodes.remove 
    '''
    for inode in clear_unused_nodes:
        if inode.type == 'TEX_IMAGE':
            all_tex_nodes.append(inode)
            print(f"{inode.name} is type {inode.type}\n")
    print(all_tex_nodes)
    for tnode in all_tex_nodes:
            #attributes = dir(tnode)
            #print(attributes)
            anode = tnode.image
            print(f"{dir(anode)}\n")
            if dir(tnode.image).count('source') > 0:# == 'FILE':
                print(f"{tnode.name} with source {tnode.image.source} located at {tnode.image.filepath}\n")
            else:
                tnode.hide
                print(f"{tnode.name} has no image source\n {tnode.location}")
                print(f"{dir(tnode)}\n")'''
    '''
            if inode.image.source:
                print(f"{inode.name} has source {inode.image.source}")
            else:
                print(f"{inode.name} has no source")'''

    # unused nodes decoration
    '''
    if unused_nodes:
        unused_frame = None
        unused_frame = node_tree.nodes.new("NodeFrame")
        unused_frame.label = "Unused"
        unused_frame.use_custom_color = True
        unused_frame.color = (0.336, 0.017, 0.026)
        idx = 0
        for node in unused_nodes:
            node.hide = True
            node.parent = unused_frame
            node.location = (0, idx * -20)
            idx = idx + 1
        unused_frame.location = (40, -160)
    '''

    # global decoration
    generated_frame = node_tree.nodes.new("NodeFrame")
    generated_frame.label = "Auto generated - don't edit manually"
    generated_frame.use_custom_color = True
    generated_frame.color = (0.066, 0.293, 0.059)
    for node in node_tree.nodes:
        if not node.parent:
            node.parent = generated_frame


#---
#--- Recreates and cleans up on demand shader nodes by preconfigured manner!
#--- Also executes on background for every texture change.
#---
#--- @class HGERecreateShaderNodes
#--- @field bl_idname string The unique identifier for this operator.
#--- @field bl_label string The label for this operator.
#--- @field bl_description string The description for this operator.
#---
#--- @function execute
#--- @param self HGERecreateShaderNodes
#--- @param context bpy.types.Context
#--- @return table
class HGERecreateShaderNodes(bpy.types.Operator):
    bl_idname = "hge.recreate_shader_nodes"
    bl_label = "Recreate shader nodes"
    bl_description = "Recreates and cleans up on demand shader nodes by preconfigured manner!\nAlso executes on background for every texture change"

    def execute(self, context):
        for object in context.scene.objects:
            if not object.material_slots:
                continue
            recreate_shader_nodes(object.material_slots[0].material.hgm_settings, context)
        return {"FINISHED"}


# these are the properties that will be visible inside Blender
#---
#--- Represents the material settings for an object in the HGE engine.
#--- This property group contains various settings that control the appearance and rendering of the material.
#---
#--- @class HGEMaterialSettings
#--- @field alpha_test_value integer The alpha test value, where pixels with alpha below this value are discarded.
#--- @field alpha_blend_mode string The alpha blending mode, which can be one of "None", "Blend", "Additive", "AdditiveLight", "Premultiplied", "Glass", "Overlay", "Exposed", or "SkyObject".
#--- @field depth_write boolean Determines if the object will be rendered in the depth buffer.
#--- @field view_dependant_opacity boolean Determines if the object's opacity will change depending on the camera angle.
#--- @field translucent_shading boolean Enables translucent shading for the material.
#--- @field two_sided_shading boolean Enables two-sided shading for the material.
#--- @field foliage_normals boolean Determines if the backface normals should be flipped when using two-sided shading for foliage.
#--- @field normal_map_as_distortion boolean Determines if the normal map should be used for distortion.
#--- @field subsurface_scattering boolean Enables subsurface scattering for the material.
#---
class HGEMaterialSettings(bpy.types.PropertyGroup):
    alpha_test_value: bpy.props.IntProperty(
        name="Alpha test value",
        description="Pixels where the alpha is below this value  re discarded",
        min=0,
        max=255,
        default=128,
        update=recreate_shader_nodes)
    alpha_blend_mode: bpy.props.EnumProperty(
        name="Alpha blending mode",
        description="Alpha Blending Mode",
        items=[
            ("1", "None", "Cutout blending"),
            ("2", "Blend", "8-bit blending"),
            ("3", "Additive", ""),
            ("4", "AdditiveLight", ""),
            ("5", "Premultiplied", ""),
            ("6", "Glass", ""),
            ("7", "Overlay", ""),
            ("8", "Exposed", ""),
            ("9", "SkyObject", "Special blend mode for sky objects (e.g. moons)"),
        ], default="1",
        update=recreate_shader_nodes)
    depth_write: bpy.props.BoolProperty(
        name="Depth write",
        description="Determines if the object will be rendered in the depth buffer",
        default=True)
    view_dependant_opacity: bpy.props.BoolProperty(
        name="View dependent opacity",
        description="Object will change their opacity depending on the camera angle",
        default=False)
    translucent_shading: bpy.props.BoolProperty(
        name="Translucent shading",
        description="Translucency",
        default=False,
        update=recreate_shader_nodes)
    two_sided_shading: bpy.props.BoolProperty(
        name="Two-sided shading",
        description="If geometry visible from both sides",
        default=False,
        update=recreate_shader_nodes)
    foliage_normals: bpy.props.BoolProperty(
        name="Foliage Normals",
        description="Used in combination with two-sided shading. When toggled the backface normals won't be flipped",
        default=False)
    normal_map_as_distortion: bpy.props.BoolProperty(
        name="Normal map as distortion",
        description="If the normal map will be used for distortion",
        default=False)
    subsurface_scattering: bpy.props.BoolProperty(
        name="Subsurface scattering",
        description="Used for human-like skin",
        default=False)
    hair: bpy.props.BoolProperty(
        name="Hair",
        description="Use for hair",
        default=False)
    blend_materials: bpy.props.BoolProperty(
        name="Blend materials",
        description="If material can be used for blending",
        default=False)
    roughness_distance_adjust: bpy.props.FloatProperty(
        name="Roughness distance adjust",
        description="Make the object appear roughner when farther away from the camera",
        min=0.0,
        max=1.0,
        default=0.0)
    depth_softness: bpy.props.IntProperty(
        name="Depth softness",
        description="Smooth blending when the object clips with another (e.g. smoke particles)",
        default=0)
    cast_shadows: bpy.props.BoolProperty(
        name="Cast shadows",
        description="If the object will cast shadows",
        default=True)
    receive_shadows: bpy.props.BoolProperty(
        name="Receive shadows",
        description="If the object will receive shadows",
        default=True)
    shadow_bias: bpy.props.EnumProperty(
        name="Shadow Bias",
        description="Will convert to shadow map depth bias based on setting.",
        items=[
            ("1", "Disable", ""),
            ("2", "Small", ""),
            ("3", "Medium", ""),
            ("4", "Large", ""),
            ("5", "LowSlope", ""),
        ], default="3")
    special: bpy.props.EnumProperty(
        name="Special",
        description="Special rendering modes. Can be used to make the object a decal or use a special water shader.",
        items=[
            ("1", "None", ""),
            ("2", "WaterNormal", ""),
            ("3", "Decal", ""),
            ("4", "WaterWaves", ""),
            ("5", "SkinnedDecal", ""),
        ], default="1")
    base_color_decal: bpy.props.BoolProperty(
        name="Base color decal",
        description="Decal that writes in the base color",
        default=True)
    normal_map_decal: bpy.props.BoolProperty(
        name="Normal map decal",
        description="Decal that writes in the normal map",
        default=True)
    rm_decal: bpy.props.BoolProperty(
        name="Roughness/metallic decal",
        description="Decal that writes in the roughness/metallic",
        default=True)
    ao_decal: bpy.props.BoolProperty(
        name="Ambient occlusion decal",
        description="Decal that writes in the ambient occlusion",
        default=True)
    triplanar_decal: bpy.props.BoolProperty(
        name="Triplanar Decal",
        description="Decal that is projected onto the surface of objects in all 3 planes",
        default=False)
    double_sided_decal: bpy.props.BoolProperty(
        name="Double-sided decal",
        description="Should the decal be applied to the backside of objects",
        default=True)
    decal_group: bpy.props.EnumProperty(
        name="Decal group",
        description="Used to specify which objects can are painted by which decals. This is property of decals AND meshes. Each group contains the one before it.",
        items=(
            ("1", "TerrainOnly", "Affect only the terrain and no objects"),
            ("2", "Terrain", "Affect the terrain and objects considered part of the terrain (e.g. rocks, grass, etc.)"),
            ("3", "Default", "Affect the terrain and all objects, except units"),
            ("4", "Unit", "Affect the terrain and all objects, including units (e.g. blood decals)"),
        ), default="3")
    no_depth_testable: bpy.props.BoolProperty(
        name="No depth testable",
        description="Objects that can have depth testing disabled",
        default=False)
    ui_element: bpy.props.BoolProperty(
        name="UI element",
        description="Objects existing in 3D but are used for UI purposes (floating icons, etc.)",
        default=False)
    cm_colors: bpy.props.IntProperty(
        name="Colorization mask colors",
        description="Number of colors in the colorization mask",
        min=1,
        max=4,
        default=1)
    terrain: bpy.props.BoolProperty(
        name="Terrain",
        description="Marks this object as terrain",
        default=False)
    deposition: bpy.props.EnumProperty(
        name="Deposition",
        description="Objects that have terrain deposition on top of them",
        items=[
            ("1", "None", "No deposition"),
            ("2", "Terrain Type", "Deposition for a specific terrain type"),
            ("3", "Terrain", "Deposition for the terrain underneath"),
        ], default="1")
    terrain_distorted_mesh: bpy.props.EnumProperty(
        name="Terrain distorted mesh",
        description="Objects that are bent along the terrain height",
        items=[
            ("1", "Disabled", "No bending along the terrain"),
            ("2", "Enabled", "Bend along the terrain"),
            ("3", "Both", "Bend along the terrain and walkable surfaces"),
        ], default="1")
    mirrorable: bpy.props.BoolProperty(
        name="Mirrorable",
        description="If the object can be mirrored dynamically",
        default=False)
    wrap: bpy.props.EnumProperty(
        name="Vertex Noise",
        description="How the game may displace the vertices",
        items=[
            ("1", "None", "No displacement"),
            ("2", "Warp", "Randomized warping"),
            ("3", "Grass", "Wind displacement for grass"),
            ("4", "Tree", "Wind displacement for trees"),
        ], default="1")
    vertex_color_usage_red: bpy.props.EnumProperty(
        name="Red channel usage",
        description="How the red vertex colors will be used",
        items=[
            ("1", "None", "Nothing"),
            ("2", "AO", "Ambient occlusion"),
            ("3", "Night emissive", "Self illumination"),
            ("4", "Warp weight XY", "Horizontal warping weight"),
            ("5", "Warp weight Z", "Vertical warping weight"),
            ("6", "Dirtiness", "Places dark/dirty spots on the object"),
        ], default="1")
    vertex_color_usage_green: bpy.props.EnumProperty(
        name="Green channel usage",
        description="How the green vertex colors will be used",
        items=[
            ("1", "None", "Nothing"),
            ("2", "AO", "Ambient occlusion"),
            ("3", "Night emissive", "Self illumination"),
            ("4", "Warp weight XY", "Horizontal warping weight"),
            ("5", "Warp weight Z", "Vertical warping weight"),
            ("6", "Dirtiness", "Places dark/dirty spots on the object"),
        ], default="1")
    vertex_color_usage_blue: bpy.props.EnumProperty(
        name="Blue channel usage",
        description="How the blue vertex colors will be used",
        items=[
            ("1", "None", "Nothing"),
            ("2", "AO", "Ambient occlusion"),
            ("3", "Night emissive", "Self illumination"),
            ("4", "Warp weight XY", "Horizontal warping weight"),
            ("5", "Warp weight Z", "Vertical warping weight"),
            ("6", "Dirtiness", "Places dark/dirty spots on the object"),
        ], default="1")
    vertex_color_usage_alpha: bpy.props.EnumProperty(
        name="Alpha channel usage",
        description="How the alpha vertex colors will be used",
        items=[
            ("1", "None", "Nothing"),
            ("2", "AO", "Ambient occlusion"),
            ("3", "Night emissive", "Self illumination"),
            ("4", "Warp weight XY", "Horizontal warping weight"),
            ("5", "Warp weight Z", "Vertical warping weight"),
            ("6", "Dirtiness", "Places dark/dirty spots on the object"),
        ], default="1")
    project_specific_0: bpy.props.BoolProperty(
        name="Custom flag 0",
        default=False)
    animation_time: bpy.props.IntProperty(
        name="Animation Time (in ms)",
        description="The loop time of the animated texture. When this is set to more than 0, the texture is treated as animated.",
        min=0,
        max=20000,
        default=0,
        update=recreate_shader_nodes)
    animation_frames_x: bpy.props.IntProperty(
        name="Animation Frames X",
        description="For animated textures: number of frames on each row.",
        min=1,
        max=100,
        default=1,
        update=recreate_shader_nodes)
    animation_frames_y: bpy.props.IntProperty(
        name="Animation Frames Y",
        description="For animated textures: number of frames on each column.",
        min=1,
        max=100,
        default=1,
        update=recreate_shader_nodes)
    base_color: bpy.props.PointerProperty(
        name="Base color",
        description="Base color image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    normal_map: bpy.props.PointerProperty(
        name="Normal map",
        description="Normal map image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    roughness_metallic_map: bpy.props.PointerProperty(
        name="Roughness/metallic",
        description="Roughness/metallic image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    ambient_occlusion_map: bpy.props.PointerProperty(
        name="Ambient occlusion",
        description="Ambient occlusion image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    self_illum_map: bpy.props.PointerProperty(
        name="Self illumination",
        description="Self illumination image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    colorization_mask: bpy.props.PointerProperty(
        name="Colorization mask",
        description="Colorization mask image",
        type=bpy.types.Image,
        update=recreate_shader_nodes)
    special_map: bpy.props.PointerProperty(
        name="Special map",
        description="Image with special usage",
        type=bpy.types.Image,
        update=recreate_shader_nodes)


#---
#--- Base class for the HGE Material panel in Blender.
#--- This class defines the basic properties and layout of the HGE Material panel.
#---
#--- @class HGEMaterialPanelBase
#--- @field bl_space_type string The Blender space type for the panel (PROPERTIES)
#--- @field bl_region_type string The Blender region type for the panel (WINDOW)
#--- @field bl_context string The Blender context for the panel (material)
#--- @field bl_options table The Blender panel options (DEFAULT_CLOSED)
#--- @field draw_section_heading function A function to draw a section heading in the panel layout
class HGEMaterialPanelBase():
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "material"
    bl_options = {"DEFAULT_CLOSED"}

    def draw_section_heading(self, text):
        row = self.layout.row()
        row.alignment = "CENTER"
        row.label(text=text)


#---
#--- The HGEMaterialPanel class is a Blender panel that extends the HGEMaterialPanelBase class and the bpy.types.Panel class. It is used to display a material panel in the Blender UI, specifically for the Haemimont material.
#---
#--- The panel is displayed in the "PROPERTIES" space type, in the "WINDOW" region type, and in the "material" context. It is also set to be initially closed by default.
#---
#--- The panel's draw method is not implemented in this code, so it will not display any custom UI elements. The functionality of the panel is likely implemented in the draw method of the HGEMaterialPanelBase class or in other related classes.
#---
class HGEMaterialPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_idname = "HGE_PT_material"
    bl_label = "Haemimont Material"

    @classmethod
    def poll(cls, context):
        return context.object and context.object.active_material

    def draw(self, context):
        pass


#---
#--- The `HGEMaterialOpenMapOp` class is a Blender operator that allows the user to open an image file and assign it to a specific material property in the Haemimont material settings.
#---
#--- The operator inherits from the `bpy.types.Operator` and `bpy_extras.io_utils.ImportHelper` classes, which provide the basic functionality for a Blender operator and the ability to handle file selection, respectively.
#---
#--- When the operator is executed, it will attempt to open the selected image file and find the corresponding `bpy.types.Image` object in the Blender data. If the image is successfully opened, it will be assigned to the material property specified by the `map_prop` attribute of the operator.
#---
#--- If the image cannot be found or an error occurs during the operation, the operator will report an error to the user.
#---
class HGEMaterialOpenMapOp(bpy.types.Operator, bpy_extras.io_utils.ImportHelper):
    bl_idname = "hge.map_open_image"
    bl_label = "Open Image"

    filter_glob: bpy.props.StringProperty(
        default="*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp;*.tga",
        options={"HIDDEN"})
    map_prop: bpy.props.StringProperty(options={"HIDDEN"})

    def execute(self, context):
        try:
            bpy.ops.image.open(filepath=self.filepath)
        except RuntimeError as e:
            self.report({"ERROR"}, str(e))
        opened_image = None
        norm_self_path = self.filepath
        norm_self_path = os.path.normpath(norm_self_path)
        norm_self_path = os.path.normcase(norm_self_path)
        for image in bpy.data.images:
            norm_image_path = bpy.path.abspath(image.filepath)
            norm_image_path = os.path.normpath(norm_image_path)
            norm_image_path = os.path.normcase(norm_image_path)
            if norm_image_path == norm_self_path:
                opened_image = image
                break

        if opened_image:
            object = context.active_object
            material = object.active_material
            hgm_settings = material.hgm_settings
            setattr(hgm_settings, self.map_prop, opened_image)
        else:
            self.report({"ERROR"}, "Failed to find opened the image")

        return {"FINISHED"}


"""
The `HGEMaterialMapsPanel` class is a Blender panel that displays the material maps for a Haemimont material.

The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.

The panel is responsible for drawing the UI elements that allow the user to manage the various material maps, such as the base color, normal map, roughness/metallic map, and others. It uses the `draw_map_prop` method to create the UI elements for each map property.

The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_maps" ID and "Maps" label.
"""
class HGEMaterialMapsPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_maps"
    bl_label = "Maps"
    bl_order = 0

    def draw_map_prop(self, hgm_settings, map_prop):
        row = self.layout.row()
        row.prop(hgm_settings, map_prop)
        op = row.operator("hge.map_open_image", text="", icon="FILE_FOLDER")
        op.map_prop = map_prop

    def draw(self, context):
        hgm_settings = context.object.active_material.hgm_settings
        self.draw_map_prop(hgm_settings, "base_color")
        self.draw_map_prop(hgm_settings, "normal_map")
        self.draw_map_prop(hgm_settings, "roughness_metallic_map")
        self.draw_map_prop(hgm_settings, "ambient_occlusion_map")
        self.draw_map_prop(hgm_settings, "self_illum_map")
        self.draw_map_prop(hgm_settings, "colorization_mask")
        self.layout.prop(hgm_settings, "cm_colors", slider=True)
        self.draw_map_prop(hgm_settings, "special_map")


#The `HGEMaterialRenderingPanel` class is a Blender panel that displays the rendering settings for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the various rendering properties, such as transparency, shading, depth, and shadows. It uses the `draw_section_heading` method to create section headings for the different groups of properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_rendering" ID and "Rendering" label. It has a `bl_order` of 1, which determines the order in which the panel is displayed in the UI.
class HGEMaterialRenderingPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_rendering"
    bl_label = "Rendering"
    bl_order = 1

    def draw(self, context):
        layout = self.layout
        hgm_settings = context.object.active_material.hgm_settings

        self.draw_section_heading("Transparency")
        layout.prop(hgm_settings, "alpha_test_value", slider=True)
        layout.prop(hgm_settings, "alpha_blend_mode")
        layout.prop(hgm_settings, "depth_write")
        layout.prop(hgm_settings, "view_dependant_opacity")

        self.draw_section_heading("Shading")
        layout.prop(hgm_settings, "translucent_shading")
        layout.prop(hgm_settings, "two_sided_shading")
        layout.prop(hgm_settings, "foliage_normals")
        layout.prop(hgm_settings, "normal_map_as_distortion")
        layout.prop(hgm_settings, "subsurface_scattering")
        layout.prop(hgm_settings, "hair")
        layout.prop(hgm_settings, "blend_materials")
        layout.prop(hgm_settings, "roughness_distance_adjust", slider=True)

        self.draw_section_heading("Depth")
        layout.prop(hgm_settings, "depth_softness")

        self.draw_section_heading("Shadows")
        layout.prop(hgm_settings, "cast_shadows")
        layout.prop(hgm_settings, "receive_shadows")
        layout.prop(hgm_settings, "shadow_bias")


#The `HGEMaterialSpecialPanel` class is a Blender panel that displays the special properties for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the various special properties, such as decal properties and flags. It uses the `draw_section_heading` method to create section headings for the different groups of properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_special" ID and "Special" label. It has a `bl_order` of 2, which determines the order in which the panel is displayed in the UI.
class HGEMaterialSpecialPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_special"
    bl_label = "Special"
    bl_order = 2

    def draw(self, context):
        layout = self.layout
        hgm_settings = context.object.active_material.hgm_settings

        layout.prop(hgm_settings, "special")

        self.draw_section_heading("Decal Properties")
        layout.prop(hgm_settings, "base_color_decal")
        layout.prop(hgm_settings, "normal_map_decal")
        layout.prop(hgm_settings, "rm_decal")
        layout.prop(hgm_settings, "ao_decal")
        layout.prop(hgm_settings, "triplanar_decal")
        layout.prop(hgm_settings, "double_sided_decal")
        layout.prop(hgm_settings, "decal_group")

        self.draw_section_heading("Flags")
        layout.prop(hgm_settings, "no_depth_testable")
        layout.prop(hgm_settings, "ui_element")


#The `HGEMaterialTerrainPanel` class is a Blender panel that displays the terrain-related properties for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the terrain-related properties, such as terrain, deposition, and terrain distorted mesh. It uses the `draw` method to create the UI layout and populate it with the relevant properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_terrain" ID and "Terrain" label. It has a `bl_order` of 3, which determines the order in which the panel is displayed in the UI.
class HGEMaterialTerrainPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_terrain"
    bl_label = "Terrain"
    bl_order = 3

    def draw(self, context):
        layout = self.layout
        hgm_settings = context.object.active_material.hgm_settings

        layout.prop(hgm_settings, "terrain")
        layout.prop(hgm_settings, "deposition")
        layout.prop(hgm_settings, "terrain_distorted_mesh")


#The `HGEMaterialVertexPanel` class is a Blender panel that displays the vertex-related properties for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the vertex-related properties, such as mirrorable, wrap, and vertex color usage. It uses the `draw` method to create the UI layout and populate it with the relevant properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_vertex" ID and "Vertex" label. It has a `bl_order` of 4, which determines the order in which the panel is displayed in the UI.
class HGEMaterialVertexPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_vertex"
    bl_label = "Vertex"
    bl_order = 4

    def draw(self, context):
        layout = self.layout
        hgm_settings = context.object.active_material.hgm_settings

        layout.prop(hgm_settings, "mirrorable")
        layout.prop(hgm_settings, "wrap")
        layout.prop(hgm_settings, "vertex_color_usage_red")
        layout.prop(hgm_settings, "vertex_color_usage_green")
        layout.prop(hgm_settings, "vertex_color_usage_blue")
        layout.prop(hgm_settings, "vertex_color_usage_alpha")


#The `HGEMaterialGameSpecificPanel` class is a Blender panel that displays game-specific properties for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the game-specific properties. It uses the `draw` method to create the UI layout and populate it with the relevant properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_game_specific" ID and "Game Specific" label. It has a `bl_order` of 5, which determines the order in which the panel is displayed in the UI.
#
#The `poll` method is used to determine whether the panel should be displayed based on the value of the `SETTINGS["mtl_prop_0_visible"]` variable.
class HGEMaterialGameSpecificPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_game_specific"
    bl_label = "Game Specific"
    bl_order = 5

    @classmethod
    def poll(cls, context):
        return SETTINGS["mtl_prop_0_visible"]

    def draw(self, context):
        hgm_settings = context.object.active_material.hgm_settings
        if SETTINGS["mtl_prop_0_visible"]:
            self.layout.prop(hgm_settings, "project_specific_0", text=SETTINGS["mtl_prop_0_name"])


#The `HGEMaterialAnimationsPanel` class is a Blender panel that displays the animation-related properties for a Haemimont material.
#
#The panel inherits from the `HGEMaterialPanelBase` and `bpy.types.Panel` classes, which provide the basic functionality for a Blender panel.
#
#The panel is responsible for drawing the UI elements that allow the user to manage the animation-related properties, such as animation time, animation frames, and animation looping. It uses the `draw` method to create the UI layout and populate it with the relevant properties.
#
#The panel is part of the "HGE_PT_material" parent panel, and has the "HGE_PT_material_animations" ID and "Animations" label. It has a `bl_order` of 6, which determines the order in which the panel is displayed in the UI.
class HGEMaterialAnimationsPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_parent_id = "HGE_PT_material"
    bl_idname = "HGE_PT_material_animations"
    bl_label = "Animations"
    bl_order = 6

    def draw(self, context):
        layout = self.layout
        hgm_settings = context.object.active_material.hgm_settings

        layout.prop(hgm_settings, "animation_time")
        layout.prop(hgm_settings, "animation_frames_x")
        layout.prop(hgm_settings, "animation_frames_y")

# animations--------------------------------------------------------------------------------------------------------------------------------------------------------

#---
#The `HGE_UL_marked_animations` class is a Blender UI list that displays a list of marked animations. This class inherits from the `bpy.types.UIList` class, which provides the basic functionality for a Blender UI list.
#
#The UI list is responsible for drawing the list of marked animations, which are represented by the `HGEMarkedAnimation` property group. The `draw_item` method is used to draw each item in the list, displaying the entity, mesh, and state information for the animation.
#
#This UI list is likely used in a Blender panel or operator to allow the user to manage the marked animations for a Haemimont material.
class HGE_UL_marked_animations(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index, flt_flag):
        anim_name = AnimationName.parse(item.prop_name)
        row = layout.row()
        row.label(text=f"{anim_name.entity}")
        row.label(text=f"{anim_name.mesh}", icon="MESH_DATA")
        row.label(text=f"{anim_name.state}", icon="ARMATURE_DATA")


#---
#Updates the properties of a marked animation.
#
#This function is called when any of the properties of a `HGEMarkedAnimation` object are updated, such as the start frame, end frame, loop animation, or root motion. It updates the corresponding properties on the animating armature object to ensure the animation is properly configured for export.
#
#@param marked_anim The `HGEMarkedAnimation` object that was updated.
#@param context The Blender context.
def update_marked_anim_props(marked_anim, context):
    marked_anim.armature_object[marked_anim.prop_name] = marked_anim.get_anim_prop_value()


#---
#The `HGEMarkedAnimation` class is a Blender property group that represents a marked animation. It contains properties that define the animation, such as the animating armature object, the animation property name, the start and end frames, whether the animation should loop, the root motion type, and whether to compensate for Z-axis movement.
#
#The `update_marked_anim_props` function is called whenever any of the properties of the `HGEMarkedAnimation` object are updated. It updates the corresponding properties on the animating armature object to ensure the animation is properly configured for export.
class HGEMarkedAnimation(bpy.types.PropertyGroup):
    armature_object: bpy.props.PointerProperty(
        name="Animating armature",
        type=bpy.types.Object)
    prop_name: bpy.props.StringProperty(
        name="Animation property name")
    frame_start: bpy.props.IntProperty(
        name="Start frame",
        min=1,
        default=1,
        update=update_marked_anim_props)
    frame_end: bpy.props.IntProperty(
        name="End frame",
        min=2,
        default=2,
        update=update_marked_anim_props)
    loop_anim: bpy.props.BoolProperty(
        name="Loop Animation",
        default=False,
        update=update_marked_anim_props)
    root_motion: bpy.props.EnumProperty(
        name="Root Motion",
        items=(
            ("None", "None", ""),
            ("CME", "CME", ""),
            ("VDA", "VDA", ""),
            ("InverseCME", "InverseCME", ""),
        ),
        default="None",
        update=update_marked_anim_props)
    compensate_z: bpy.props.BoolProperty(
        name="Compensate Z",
        default=True,
        update=update_marked_anim_props)

    def get_prop_name(self):
        return self.prop_name

    def get_export_prop_name(self):
        return AnimationName.parse(self.prop_name).get_export_name()

    def get_anim_prop_value(self):
        return ":".join([
            self.root_motion,
            str(self.frame_start),
            str(self.frame_end),
            str(self.loop_anim),
            str(self.compensate_z),
        ])

    def get_errors(self):
        # TODO find errors
        pass


#--- Represents the animation settings for the HGE (Hybrid Game Engine) exporter.
#---
#--- This property group contains various settings related to the animation export process,
#--- such as the animation property name, start and end frames, loop animation, root motion,
#--- and Z-axis compensation.
#---
#--- The settings in this property group are used to configure the animation export behavior
#--- and can be accessed and modified through the Blender UI or Python API.
class HGEAnimationSettings(bpy.types.PropertyGroup):
    mark_anim_mesh: bpy.props.PointerProperty(
        name="Mesh",
        description="The mesh to be marked and used for the new animation. It must be skinned. You can reuse meshes in different states",
        type=bpy.types.Object)
    mark_anim_armature: bpy.props.PointerProperty(
        name="Armature",
        description="The armature to be marked and used for the new animtation. You can reuse armatures in different states",
        type=bpy.types.Object)
    mark_anim_state: bpy.props.StringProperty(
        name="State",
        description="The name of the animated state. Can be the same as the selected mesh")
    mark_anim_frame_start: bpy.props.IntProperty(
        name="Start frame",
        min=1,
        default=1)
    mark_anim_frame_end: bpy.props.IntProperty(
        name="End frame",
        min=2,
        default=2)
    marked_animations: bpy.props.CollectionProperty(
        name="Marked animations",
        type=HGEMarkedAnimation)
    active_marked_animation_index: bpy.props.IntProperty(
        name="Active marked animation index")


#---
#Represents an operator that allows the user to mark an animation in the Blender scene for export to the Hybrid Game Engine (HGE).
#
#This operator is responsible for validating the user's input, detecting any errors, and setting up the necessary animation settings in the HGE property group. It is invoked when the user selects the "Mark animation" option in the Blender UI.
#
#The operator checks that the user has selected a valid mesh and armature, and that the animation state name is properly formatted. If any errors are detected, it reports them to the user and cancels the operation.
#
#Once the input is validated, the operator updates the HGE animation settings with the user's selections, such as the start and end frames, and adds the marked animation to the list of animations to be exported.
class HGEMarkAnimationOp(bpy.types.Operator):
    bl_idname = "hge.mark_animation"
    bl_label = "Mark animation"

    def invoke(self, context, event):
        scene = context.scene
        hge_settings = context.scene.hge_settings
        hge_settings.mark_anim_frame_start = scene.frame_start
        hge_settings.mark_anim_frame_end = scene.frame_end
        wm = context.window_manager
        return wm.invoke_props_dialog(self, width=500)

    def execute(self, context):
        hge_settings = context.scene.hge_settings

        mark_anim_mesh = hge_settings.mark_anim_mesh

        # detect errors and report
        errors = []
        if not hge_settings.mark_anim_mesh:
            errors.append("Select the animated mesh")
        elif hge_settings.mark_anim_mesh.type != "MESH":
            errors.append("Select an entity mesh (selected object is not a mesh)")
        else:
            hge_obj_settings = hge_settings.mark_anim_mesh.hge_obj_settings
            if hge_obj_settings.resolve_role() != "MESH" or not hge_obj_settings.mesh:
                errors.append("Select an properly set up entity mesh (check the Object tab)")
            else:
                mark_anim_mesh = hge_settings.mark_anim_mesh
                if not hge_obj_settings.is_skinned():
                    errors.append("Skin the mesh before marking for animation")
        if not hge_settings.mark_anim_armature:
            errors.append("Select the animating armature")
        elif hge_settings.mark_anim_armature.type != "ARMATURE":
            errors.append("Select an armature object (selected object is not an armature)")
        if not hge_settings.mark_anim_state:
            errors.append("Enter a name for the animated state")
        elif not re.match(r"^[a-zA-Z0-9_]+$", hge_settings.mark_anim_state):
            errors.append("Remove illegal characters from the state name")
        else:
            if mark_anim_mesh:
                entity = mark_anim_mesh.hge_obj_settings.entity
                if hge_settings.mark_anim_state in find_states(entity):
                    if hge_settings.mark_anim_state != mark_anim_mesh.hge_obj_settings.state:
                        errors.append("Enter a unique state name")
        if errors:
            message = "Before you can add an animation you need to:"
            for i in range(len(errors)):
                message = f"{message}\n{i+1}) {errors[i]}"
            self.report({"ERROR"}, message)
            return {"CANCELLED"}

        entity_name = mark_anim_mesh.hge_obj_settings.get_mesh_name_helper()
        anim_name = AnimationName()
        anim_name.entity = entity_name.name
        anim_name.mesh = entity_name.mesh
        anim_name.state = hge_settings.mark_anim_state
        anim_name_str = str(anim_name)

        armature_object = hge_settings.mark_anim_armature
        if anim_name_str in armature_object.keys():
            self.report({"ERROR"}, "This animation already exists")
            return {"CANCELLED"}
        else:
            marked_anim = hge_settings.marked_animations.add()
            marked_anim.name = f"{anim_name.entity} {anim_name.state}"
            marked_anim.armature_object = armature_object
            marked_anim.prop_name = anim_name_str
            # print(marked_anim.prop_name)
            marked_anim.frame_start = hge_settings.mark_anim_frame_start
            marked_anim.frame_end = hge_settings.mark_anim_frame_end
            armature_object[anim_name_str] = marked_anim.get_anim_prop_value()
            armature_object[anim_name.get_export_name()] = True
            self.report({"INFO"}, "The animation was added")
            return {"FINISHED"}

    def draw(self, context):
        hge_settings = context.scene.hge_settings
        self.layout.prop(hge_settings, "mark_anim_mesh", icon="OUTLINER_OB_MESH")
        self.layout.prop(hge_settings, "mark_anim_armature", icon="OUTLINER_OB_ARMATURE")
        self.layout.prop(hge_settings, "mark_anim_state", icon="ARMATURE_DATA")
        self.layout.prop(hge_settings, "mark_anim_frame_start")
        self.layout.prop(hge_settings, "mark_anim_frame_end")


#---
#Operator: HGEUnmarkAnimationOp
#Description: This operator is used to unmark an animation that has been previously marked for export.
class HGEUnmarkAnimationOp(bpy.types.Operator):
    bl_idname = "hge.unmark_animation"
    bl_label = "Unmark animation"

    def execute(self, context):
        hge_settings = context.scene.hge_settings
        active_marked_anim = None
        if len(hge_settings.marked_animations) > 0:
            active_marked_anim = hge_settings.marked_animations[hge_settings.active_marked_animation_index]
        if active_marked_anim:
            armature_object = active_marked_anim.armature_object
            prop_name = active_marked_anim.get_prop_name()
            export_prop_name = active_marked_anim.get_export_prop_name()
            if prop_name in armature_object:
                del armature_object[prop_name]
            if export_prop_name in armature_object:
                del armature_object[export_prop_name]
            hge_settings.marked_animations.remove(hge_settings.active_marked_animation_index)
        return {"FINISHED"}

# export--------------------------------------------------------------------------------------------------------------------------------------------------------

#---
#--- Represents a property group for HGE animation exports.
#--- This property group contains various properties related to the animation export, such as the animation name, armature name, property name, and whether the animation should be exported.
#---
#--- @class HGEAnimExportProperty
#--- @field label string The animation name.
#--- @field armature string The armature name.
#--- @field property string The property name.
#--- @field export boolean Whether the animation should be exported.
class HGEAnimExportProperty(bpy.types.PropertyGroup):
    label: bpy.props.StringProperty(name="Animation Name")
    armature: bpy.props.StringProperty(name="Armature Name")
    property: bpy.props.StringProperty(name="Property Name")
    export: bpy.props.BoolProperty(
        name="Export",
        description="If this animation should be exported",
        default=True)


#---
#--- Represents a property group for HGE mesh exports.
#--- This property group contains various properties related to the mesh export, such as the mesh name, entity name, LOD, and whether the mesh should be exported.
#---
#--- @class HGEMeshExportProperty
#--- @field label string The mesh name.
#--- @field entity string The entity name.
#--- @field mesh string The mesh name.
#--- @field lod string The LOD.
#--- @field export boolean Whether the mesh should be exported.
#---
#--- @function get_key()
#--- Returns a unique key for this mesh export property.
#---
#--- @function matches_entity_name(entity_name)
#--- Checks if this mesh export property matches the given entity name.
#--- @param entity_name table The entity name to check against.
#--- @return boolean True if the mesh export property matches the entity name, false otherwise.
class HGEMeshExportProperty(bpy.types.PropertyGroup):
    label: bpy.props.StringProperty(name="Mesh Name")
    entity: bpy.props.StringProperty(name="Entity Name")
    mesh: bpy.props.StringProperty(name="Mesh Name")
    lod: bpy.props.StringProperty(name="LOD")
    export: bpy.props.BoolProperty(
        name="Export",
        description="If this mesh should be exported",
        default=True)

    def get_key(self):
        return f"{self.entity}:{self.mesh}:{self.lod}"

    def matches_entity_name(self, entity_name):
        return (
            self.entity == entity_name.name and
            self.mesh == entity_name.mesh and
            self.lod == entity_name.lod)


#---
#--- Represents a context manager for exporting animations.
#--- When entering the context, it clips the scene animation to the specified start and end frames.
#--- When exiting the context, it reverts the scene animation to the original start and end frames.
#---
#--- @class AnimExportContext
#--- @param scene table The Blender scene to export animations from.
#--- @param frame_start number The start frame for the exported animation.
#--- @param frame_end number The end frame for the exported animation.
#---
class AnimExportContext:
    def __init__(self, scene, frame_start, frame_end):
        self.scene = scene
        self.frame_start = frame_start
        self.frame_end = frame_end

    def __enter__(self):
        print("[HG] Clipping scene animation to fit the exported animation")
        self.old_frame_start = self.scene.frame_start
        self.old_frame_end = self.scene.frame_end
        self.scene.frame_start = self.frame_start
        self.scene.frame_end = self.frame_end

    def __exit__(self, ex_type, ex_value, ex_traceback):
        print("[HG] Reverting scene animation clipping")
        self.scene.frame_start = self.old_frame_start
        self.scene.frame_end = self.old_frame_end        


#---
#--- Represents a context manager for managing object names during the export process.
#--- When entering the context, it assigns special names to objects in the scene.
#--- When exiting the context, it reverts the object names back to their original names.
#---
#--- @class ObjectNamesExportContext
#--- @param context table The Blender context to operate on.
#---
class ObjectNamesExportContext:
    def __init__(self, context):
        self.context = context

    def __enter__(self):
        print("[HG] Assigning special names")
        self.old_names = self.__assign_hge_names(self.context)

    def __exit__(self, ex_type, ex_value, ex_traceback):
        print("[HG] Reverting special names")
        self.__revert_hge_names(self.old_names)

    def __assign_hge_names(self, context):
        old_names = {}
        new_names = set()
        for object in context.scene.objects:
            old_names[object] = object.name
            new_name = object.hge_obj_settings.get_hge_name()
            if not new_name:
                continue
            idx = 1
            while new_name in new_names:
                new_name = object.hge_obj_settings.get_hge_name(idx)
                idx = idx + 1
            new_names.add(new_name)
            # print(f"[HG] Rename '{object.name}' to '{new_name}'")
            object.name = new_name
        return old_names

    def __revert_hge_names(self, old_names):
        for object, old_name in old_names.items():
            object.name = old_name


#---
#--- Represents a context manager for managing waypoints during the export process.
#--- When entering the context, it sets up waypoints for objects in the scene.
#--- When exiting the context, it reverts the waypoints back to their original state.
#---
#--- @class WaypointsExportContext
#--- @param context table The Blender context to operate on.
#---
class WaypointsExportContext:
    def __init__(self, context):
        self.context = context

    def __enter__(self):
        print("[HG] Setting up waypoints for export")
        self.waypoints, self.attaches = self.__setup_waypoints(self.context)

    def __exit__(self, ex_type, ex_value, ex_traceback):
        print("[HG] Reverting waypoints")
        try:
            self.__revert_waypoints(self.waypoints)
        except:
            raise
        finally:
            self.__revert_names(self.attaches)

    def __setup_waypoints(self, context):
        waypoints, attaches = [], []
        chains_count = 0
        for parent in context.scene.objects:
            if parent.type != "MESH":
                continue

            for child in parent.children:
                if not is_attach(child.name) or child.type != "CURVE":
                    continue

                new_waypoints = self.__setup_one_waypoint(parent, child, chains_count)
                chains_count += 1
                child.name = child.name[1:]
                # print(f"[HG] Hide attach name: {child.name}")
                attaches.append(child)
                waypoints.extend(new_waypoints)

        return waypoints, attaches

    def __setup_one_waypoint(self, parent, child, chain_idx):
        child_name = child.name
        regex_result = re.match(r"^-(.*?)(\.\d+)?$", child_name, flags=0)
        if regex_result:
            child_name = f"-{regex_result.group(1)}"
        if prop_exists(child, "attach"):
            child_name += str(child["attach"])
        child_name_pieces = child_name.split(";")

        new_waypoints = []
        # print(f"[HG] Selected object type: {child.type}")
        # print(f"[HG] Splines count: {len(child.data.splines)}")
        for spline in child.data.splines:
            # print(f"[HG] Points count: {len(spline.points)}")
            for i in range(len(spline.points)):
                point = spline.points[i]
                # print(f"[HG] Coordinates: {point.co}")
                transform = child.matrix_world * parent.matrix_world.inverted()
                location = transform @ point.co
                bpy.ops.object.empty_add(location=location.xyz)
                waypoint_obj = bpy.data.objects[bpy.context.active_object.name]
                waypoint_obj.parent = parent
                new_waypoints.append(waypoint_obj)

                waypoint_obj.name = f"{child_name_pieces[0]};"
                additional_name = ""
                if i == 0:
                    for j in range(1, len(child_name_pieces)):
                        additional_name += child_name_pieces[j] + ","
                additional_name += f"chain={chain_idx},waypoint={i+1}"
                waypoint_obj["attach"] = additional_name

        return new_waypoints

    def __revert_waypoints(self, waypoints):
        bpy.ops.object.select_all(action="DESELECT")
        for waypoint_obj in waypoints:
            waypoint_obj.select_set(True)
        bpy.ops.object.delete()
    
    def __revert_names(seff, attaches):
        for attach in attaches:
            attach.name = f"-{attach.name}"



"""
Operator for exporting entities with meshes and animations.

This operator opens an export dialog box with a list of items and settings for exporting entities. It allows the user to select which meshes and animations to export.
"""
class HGEExportOp(bpy.types.Operator):
    """Operator for exporting entities with meshes and animations.

    This operator opens an export dialog box with a list of items and settings for exporting entities. It allows the user to select which meshes and animations to export.

    Attributes:
        bl_idname (str): The identifier name for the operator.
        bl_label (str): The label displayed for the operator in the user interface.
        bl_description (str): The description of the operator displayed in the user interface.
        export_meshes (bool): Flag indicating whether to export meshes.
        export_anims (bool): Flag indicating whether to export animations.
        animations (CollectionProperty): Collection of metadata for each exported animation.
        entity_meshes (CollectionProperty): Collection of metadata for each exported mesh.
        entity_mesh_objects (dict): Dictionary mapping entity mesh keys to the corresponding objects.

    Methods:
        invoke(self, context, event): Invoked when the operator is called.
        __register_mesh(self, obj): Registers a mesh for export.
        __register_armature(self, obj): Registers an armature for export.
        execute(self, context): Executes the export operation.
        __find_anim_range(self, context): Finds the animation range for the export.
        __mark_objects_for_export(self, context): Marks objects for export based on settings.
        __prepare_materials(self): Prepares materials for export.
        __prepare_one_material(self, material): Prepares a single material for export.
    """
class HGEExportOp(bpy.types.Operator):
    bl_idname = "hge.export_dialog"
    bl_label = "Export entity"
    bl_description = "Opens export dialog box with list of items and settings"

    #use_selection: bpy.props.BoolProperty(
    #    name="Export only selected",
    #    description="Only entities in the current selection will be exported",
    #    default=True)
    export_meshes: bpy.props.BoolProperty(
        name="Export meshes",
        description="Opens a dialog box with list of eligable meshes\nand settings for their export.\nYou can deselect unwanterd meshes for export",
        default=True)
    export_anims: bpy.props.BoolProperty(
        name="Export animations",
        description="Opens a dialog box with list of eligable animations\nand settings for their export.\nYou can deselect unwanterd animations for export",
        default=True)

    animations: bpy.props.CollectionProperty(
        name="Animations",
        description="Metadata for each exported animation",
        type=HGEAnimExportProperty)
    entity_meshes: bpy.props.CollectionProperty(
        name="Meshes",
        description="Metadata for each exported mesh",
        type=HGEMeshExportProperty)
    entity_mesh_objects: dict

    def invoke(self, context, event):
        self.animations.clear()
        self.entity_meshes.clear()
        self.entity_mesh_objects = dict()
        # http://blender.stackexchange.com/questions/1779/dynamic-creation-of-properties-for-export-script
        # add properties for each mesh & animation
        scene = context.scene
        for obj in scene.objects:
            if obj.type == "MESH":
                self.__register_mesh(obj)
            elif obj.type == "ARMATURE":
                self.__register_armature(obj)

        wm = context.window_manager
        return wm.invoke_props_dialog(self, width=500)

    def __register_mesh(self, obj):
        hge_obj_settings = obj.hge_obj_settings
        if hge_obj_settings.resolve_role() != "MESH" or not hge_obj_settings.is_valid():
            return
            
        entity_name = hge_obj_settings.get_mesh_name_helper()

        ent_mesh = None
        for ent_mesh2 in self.entity_meshes:
            pass


        if not ent_mesh:
            pass


        # same format as in HGEMeshExportProperty.get_key()
        entity_mesh_key = f"{entity_name.name}:{entity_name.mesh}:{entity_name.lod}"
        if entity_mesh_key not in self.entity_mesh_objects:
            pass

        self.entity_mesh_objects[entity_mesh_key].add(obj)
        entity_metadata = self.entity_meshes.add()
        entity_metadata.label = entity_label
        entity_metadata.entity = entity_name.name
        entity_metadata.mesh = entity_name.mesh
        entity_metadata.lod = str(entity_name.lod)

        # same format as in HGEMeshExportProperty.get_key()
        entity_mesh_key = f"{entity_name.name}:{entity_name.mesh}:{entity_name.lod}"
        if entity_mesh_key not in self.entity_mesh_objects:
            self.entity_mesh_objects[entity_mesh_key] = set()
        self.entity_mesh_objects[entity_mesh_key].add(obj)

    def __register_armature(self, obj):
        for key, val in obj.items():
            anim_name = AnimationName.parse(key)
            if not anim_name:
                continue

            export_anim_name = anim_name.get_export_name()
            if not prop_exists(obj, export_anim_name):
                obj[export_anim_name] = True

            # prop value format: root_motion:frame_start:frame_end:loop_anim:compensate_z
            prop_tokens = val.split(":")
            root_motion = prop_tokens[0]
            frame_start = prop_tokens[1]
            frame_end = prop_tokens[2]
            anim_label = "; ".join([
                f"State:{anim_name.state}",
                f"Entity:{anim_name.entity}",
                f"Mesh:{anim_name.mesh}"
                f"Motion:{root_motion}",
                f"Start:{frame_start}",
                f"End:{frame_end}",
            ])

            anim_metadata = self.animations.add()
            anim_metadata.label = anim_label
            anim_metadata.armature = obj.name
            anim_metadata.property = export_anim_name
            anim_metadata.export = obj[export_anim_name]

    def execute(self, context):
        print(f"[HG] Beginning export...")
        
        
        current_mode = bpy.context.window.workspace.name
        print(f"Current mode = {current_mode}")
        print("[HG] Switching to 'Modeling' workspace and object mode")
        bpy.context.window.workspace = bpy.data.workspaces['Modeling']
        bpy.ops.object.mode_set(mode='OBJECT')

        # mark animations for export
        for anim_metadata in self.animations:
            armature = context.scene.objects[anim_metadata.armature]
            armature[anim_metadata.property] = anim_metadata.export
        self.animations.clear()

        # mark meshes for export
        for entity_metadata in self.entity_meshes:
            for obj in self.entity_mesh_objects[entity_metadata.get_key()]:
                obj.hge_export = entity_metadata.export
        self.entity_meshes.clear()

        # basically copies everything from HGEMaterialSettings
        # into custom properties according to MATERIAL_PROPERTIES
        self.__prepare_materials()

        # shrink animation range
        scene = context.scene
        anim_start, anim_end = self.__find_anim_range(context)
        with AnimExportContext(scene, anim_start, anim_end):
            with ObjectNamesExportContext(context):
                # splines represent sequences of spots; each point of a spline
                # gets converted into a separate spot (the original object is hidden)
                with WaypointsExportContext(context):
                    self.__mark_objects_for_export(context)

                    # export .FBX
                    filename = os.path.basename(bpy.data.filepath)
                    fbx_dirname = os.path.join(os.getenv("APPDATA"), SETTINGS["appid"], "ModAssets", "FBX")
                    if not os.path.isdir(fbx_dirname):
                        os.makedirs(fbx_dirname)
                    fbx_filename = os.path.splitext(filename)[0] + ".fbx"
                    fbx_filepath = os.path.join(fbx_dirname, fbx_filename)
                    export_result = self.__export_fbx(fbx_filepath)

        if "FINISHED" not in export_result:
            self.report({"ERROR"}, ".FBX export failed.")
            print(f"[HG] Export failed!")
            return {"CANCELLED"}

        ap_success = self.__run_assets_processor(fbx_filepath)
        if not ap_success:
            self.report({"ERROR"}, "Failed to invoke the AssetsProcessor.")
            print(f"[HG] Export failed!")
            return {"CANCELLED"}

        self.report({"INFO"}, "HGE export finished")
        print(f"[HG] Export finished!")
        print(f"[HG] Switching to previous workspace {current_mode}")
        bpy.context.window.workspace = bpy.data.workspaces[current_mode]
        return {"FINISHED"}

    def __find_anim_range(self, context):
        scene = context.scene
        min_frame = scene.frame_start
        max_frame = scene.frame_end
        for object in scene.objects:
            if object.type != "ARMATURE":
                continue
            bones = object.data.bones
            for bone in bones:
                keys = bone.keys()
                for key in keys:
                    anim_name = AnimationName.parse(key)
                    if not anim_name:
                        continue
                    prop = bone[key]
                    # prop format: root:frame_start:frame_end
                    tokens_prop = prop.split(":")
                    if len(tokens_prop) != 3:
                        continue
                    frame_start = int(tokens_prop[1])
                    frame_end = int(tokens_prop[2])
                    if min_frame > frame_start:
                        min_frame = frame_start
                    if max_frame < frame_end:
                        max_frame = frame_end

        return min_frame, max_frame

    def __mark_objects_for_export(self, context):
        for object in context.scene.objects:
            if object.hge_obj_settings.resolve_role() != "MESH" or not object.hge_obj_settings.is_valid():
                object.hge_export = self.export_meshes and (not self.use_selection or object.hge_export)

    def __prepare_materials(self):
        for obj in bpy.data.objects:
            if obj.type != "MESH":
                continue
            if obj.hge_obj_settings.resolve_role() != "MESH" or not obj.hge_obj_settings.is_valid():
                continue

            print(f"[HG] Preparing material for '{obj.name}'")
            obj_has_materials = False
            for slot in obj.material_slots:
                if slot.material:
                    self.__prepare_one_material(slot.material)
                    obj_has_materials = True

            # There is no materials for this mesh.
            # Add a default material and try again.
            if not obj_has_materials:
                new_material = bpy.data.materials.new(name="Material")
                obj.data.materials.append(new_material)
                for slot in obj.material_slots:
                    if slot.material:
                        self.__prepare_one_material(slot.material)

    def __prepare_one_material(self, material):
        # reset properties
        remove_material_props(material)
        add_material_props(material)
        # copy settings into the material's custom properties
        hgm_settings = material.hgm_settings
        for prop in MATERIAL_PROPERTIES:
            if not prop.settings_name:
                continue  # Add an indented block here to fix the indentation error
            settings_value = getattr(hgm_settings, prop.settings_name)
            if prop.map:
                if settings_value:
                    material[prop.id] = bpy.path.abspath(settings_value.filepath)
                else:
                    material[prop.id] = ""
            elif isinstance(material, bool):
                material[prop.id] = 1 if settings_value else 0
            else:
                material[prop.id] = settings_value

    def __export_fbx(self, fbx_filepath):
        print(f"[HG] Exporting FBX to {fbx_filepath}...")
        if os.path.exists(fbx_filepath):
            os.remove(fbx_filepath)
        if self.use_selection:
            print(f"[HG] Exporting only selected entities...")
        return bpy.ops.export_scene.fbx(
            axis_forward="Y",
            axis_up="Z",
            filepath=fbx_filepath,
            use_selection=self.use_selection,
            # use_active_collection=False,
            # global_scale=1.0,
            # apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_ALL",
            # use_space_transform=True,
            # bake_space_transform=False,
            object_types={"ARMATURE", "OTHER", "MESH", "EMPTY"},
            # use_mesh_modifiers=True,
            # use_mesh_modifiers_render=True,
            # mesh_smooth_type="OFF",
            # use_subsurf=False,
            # use_mesh_edges=False,
            # use_tspace=False,
            use_custom_props=True,
            add_leaf_bones=False,
            # primary_bone_axis="Y",
            # secondary_bone_axis="X",
            # use_armature_deform_only=False,
            # armature_nodetype="NULL",
            # bake_anim=True,
            # bake_anim_use_all_bones=True,
            bake_anim_use_nla_strips=False,
            bake_anim_use_all_actions=False,
            # bake_anim_force_startend_keying=True,
            # bake_anim_step=1.0,
            # bake_anim_simplify_factor=1.0,
            # path_mode="AUTO",
            # embed_textures=False,
            batch_mode="OFF",
            use_batch_own_dir=False,
            # use_metadata=True,
        )

    def __run_assets_processor(self, fbx_filepath):
        print(f"[HG] Starting AssetsProcessor...")
        assets_proc_paths = []
        # read special environment variable
        hgeap = os.getenv("HGEAP")
        if hgeap:
            print("[HG] Looking for AssetsProcessor using HGEAP")
            assets_proc_paths.append(hgeap)
        # read trunk environment variable
        trunk_path = os.getenv('HGETrunkRoot')
        if trunk_path:
            print("[HG] Looking for AssetsProcessor in trunk directory")
            assets_proc_paths.append(os.path.join(trunk_path, "Tools", "AssetsProcessor", "Bin", "AssetsProcessor.exe"))
        # read last game launch location from registry
        appid = SETTINGS["appid"]
        registry_cmd = f"reg query \"HKEY_CURRENT_USER\\SOFTWARE\\Haemimont Games\\{appid}\" /v Path"
        registry_result = subprocess.check_output(registry_cmd, stderr=subprocess.STDOUT).decode("ascii")
        registry_result = re.search(r"REG_SZ\s*(.*)\\", registry_result)
        if registry_result:
            print("[HG] Looking for AssetsProcessor in game directory")
            assets_proc_paths.append(os.path.join(registry_result.group(1), "ModTools", "AssetsProcessor", "AssetsProcessor.exe"))
        # read this file's location
        own_path = os.path.realpath(__file__)
        if own_path:
            print(f"[HG] Looking for AssetsProcessor in exporter directory {own_path}")
            assets_proc_paths.append(os.path.join(os.path.dirname(own_path), "AssetsProcessor", "AssetsProcessor.exe"))

        assets_proc_paths = [os.path.normpath(path) for path in assets_proc_paths]
        assets_proc_paths = [path for path in assets_proc_paths if os.path.isfile(path)]
        if not assets_proc_paths:
            return
        asset_prop_args = f"\"{assets_proc_paths[0]}\" \"{fbx_filepath}\" -globalappdirs"
        print(f"[HG] AssetProcessor cmd line: {asset_prop_args}")
        os.system(f"\"{asset_prop_args}\"")
        return True

    def draw(self, context):
        self.layout.label(text="What to export:", icon='MENU_PANEL')

        if self.export_meshes:
            for entity_metadata in self.entity_meshes:
                label_pieces = []
                for obj in self.entity_mesh_objects[entity_metadata.get_key()]:
                    hge_obj_settings = obj.hge_obj_settings
                    if hge_obj_settings.resolve_role() != "MESH" or not obj.hge_obj_settings.is_valid():
                        continue
                    entity_name = hge_obj_settings.get_mesh_name_helper()
                    if entity_name.state:
                        label_pieces.append(f"s={entity_name.state}")
                    if entity_name.inherit:
                        label_pieces.append(f"i={entity_name.inherit}")
                    if entity_name.comment:
                        label_pieces.append(entity_name.comment)

                states_comments = ", ".join(label_pieces)
                label_text = f"{entity_metadata.label} ({states_comments})"
                self.layout.prop(entity_metadata, "export", text=label_text, icon="MESH_DATA")

        if self.export_anims:
            for i in range(len(self.animations)):
                anim_metadata = self.animations[i]
                self.layout.prop(anim_metadata, "export", text=anim_metadata.label, icon="ARMATURE_DATA")

        self.layout.prop(self, "use_selection", expand=True)

# user interface--------------------------------------------------------------------------------------------------------------------------------------------------------

#---
#Provides a base class for HGE toolbar panels in the Blender UI.
#This class is used as a base for various HGE toolbar panels that are displayed in the Blender 3D viewport.
#It likely contains common functionality and properties shared across the different HGE toolbar panels.
class HGEToolbarBase:
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "HGE Tools"

"""
Provides an operator that opens the output directory for exported entities.

This operator is used to open the directory where exported entities are saved, allowing the user to easily access the exported files.
"""
class HGEOpenOutputDirOp(bpy.types.Operator):
    bl_idname = "hge.open_output_dir"
    bl_label = "Open output directory"
    bl_description = "Opens output directory for exports"

    def execute(self, context):
        dir = os.path.join(os.getenv("APPDATA"), SETTINGS["appid"], "ExportedEntities")
        bpy.ops.wm.path_open(filepath=dir)
        return {"FINISHED"}


#This class represents the HGE Tools toolbar panel in the Blender 3D viewport. It is a subclass of the `HGEToolbarBase` class and the `bpy.types.Panel` class, which provides the base functionality for a Blender UI panel.
#
#The `HGEToolbarVersion` panel displays information about the version of the HGE Exporter, including the game ID and the version number. It also provides two operators: one to recreate the shader nodes, and another to open the output directory for exported entities.
class HGEToolbarVersion(HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_toolbar_version"
    bl_label = "HGE Tools"
    bl_order = 0

    def draw(self, context):
        version = SETTINGS["version"]
        version_str = ".".join([str(v) for v in version])
        game = SETTINGS["appid"]
        self.layout.label(text=f"{game} Exporter v{version_str}")
        self.layout.operator("hge.recreate_shader_nodes")
        self.layout.operator("hge.open_output_dir")


#This class represents the HGE Tools toolbar panel in the Blender 3D viewport. It is a subclass of the `HGEToolbarBase` class and the `bpy.types.Panel` class, which provides the base functionality for a Blender UI panel.
#
#The `HGEToolbarObject` panel displays settings related to the object being exported, such as its name, mesh, and state. It likely contains common functionality and properties shared across the different HGE toolbar panels.
class HGEToolbarObject(HGEObjectSettingsPanelBase, HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_object_settings_asdf"
    bl_label = "Object"
    bl_order = 1


#This class represents the HGE Tools toolbar panel in the Blender 3D viewport. It is a subclass of the `HGEToolbarBase` class and the `bpy.types.Panel` class, which provides the base functionality for a Blender UI panel.
#
#The `HGEToolbarAnimations` panel displays a list of animations that have been marked for export, along with settings for each animation such as the start and end frames, loop animation, compensate Z, and root motion. It allows the user to add and remove animations from the list.
class HGEToolbarAnimations(HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_animations"
    bl_label = "Animations"
    bl_order = 2

    def draw(self, context):
        hge_settings = context.scene.hge_settings

        anims_titles_row = self.layout.row()
        anims_titles_row.column().label(text="Entity")
        anims_titles_row.column().label(text="Mesh")
        anims_titles_row.column().label(text="State")

        anims_row = self.layout.row()
        anims_row.template_list(
            "HGE_UL_marked_animations",
            "",
            hge_settings,
            "marked_animations",
            hge_settings,
            "active_marked_animation_index",
            sort_lock=True)

        anim_ops_col = anims_row.column()
        anim_ops_col.operator("hge.mark_animation", icon="ADD", text="")
        anim_ops_col.operator("hge.unmark_animation", icon="REMOVE", text="")

        active_marked_anim = None
        if len(hge_settings.marked_animations) > 0:
            active_marked_anim = hge_settings.marked_animations[hge_settings.active_marked_animation_index]
        if active_marked_anim:
            self.layout.prop(active_marked_anim, "frame_start")
            self.layout.prop(active_marked_anim, "frame_end")
            self.layout.prop(active_marked_anim, "loop_anim")
            self.layout.prop(active_marked_anim, "compensate_z")
            self.layout.prop(active_marked_anim, "root_motion")


#This class represents the HGE Tools toolbar panel in the Blender 3D viewport. It is a subclass of the `HGEToolbarBase` class and the `bpy.types.Panel` class, which provides the base functionality for a Blender UI panel.
#
#The `HGEToolbarStatistics` panel displays various statistics about the objects in the scene that are relevant to the HGE exporter, such as the number of entities, states, mesh objects, and animations. It also identifies any objects with errors that may prevent them from being exported correctly.
class HGEToolbarStatistics(HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_statistics"
    bl_label = "Statistics"
    bl_order = 3

    def draw(self, context):
        entities = set()
        states = set()
        meshes, meshes_with_errors = [], []
        spots, spots_with_errors = [], []
        surfaces, surfaces_with_errors = [], []
        animations, animations_with_errors = [], []
        ignored = []
        for object in context.scene.objects:
            role = object.hge_obj_settings.resolve_role()
            if role == "MESH":
                meshes.append(object)
                if not object.hge_obj_settings.is_valid():
                    meshes_with_errors.append(object)
                else:
                    if object.hge_obj_settings.entity:
                        entities.add(object.hge_obj_settings.entity)
                    if object.hge_obj_settings.state:
                        states.add(object.hge_obj_settings.state)
            elif role == "SPOT":
                spots.append(object)
                if not object.hge_obj_settings.is_valid():
                    spots_with_errors.append(object)
            elif role == "SURFACE":
                surfaces.append(object)
                if not object.hge_obj_settings.is_valid():
                    surfaces_with_errors.append(object)
            elif object.type == "ARMATURE":
                for prop in object.keys():
                    anim_name = AnimationName.parse(prop)
                    if not anim_name:
                        continue
                    animations.append((object, prop))
                    states.add(anim_name.state)
            elif role == "IGNORED":
                ignored.append(object)
        """for anim in animations:
            anim_name = AnimationName.parse(anim[1])
            if anim_name.entity not in entities:
                animations_with_errors.append(anim_name)"""
        self.layout.label(text=f"Entities: {len(entities)}")
        self.layout.label(text=f"States: {len(states)}")
        self.layout.label(text=f"Mesh objects: {len(meshes)} ({len(meshes_with_errors)} errors)")
        if meshes_with_errors:
            for i in range(len(meshes_with_errors)):
                self.layout.label(text=f"{i+1}) {meshes_with_errors[i].name}", icon="ERROR")
        self.layout.label(text=f"Spot objects: {len(spots)} ({len(spots_with_errors)} errors)")
        if spots_with_errors:
            for i in range(len(spots_with_errors)):
                self.layout.label(text=f"{i+1}) {spots_with_errors[i].name}", icon="ERROR")
        self.layout.label(text=f"Surface objects: {len(surfaces)} ({len(surfaces_with_errors)} errors)")
        if surfaces_with_errors:
            for i in range(len(surfaces_with_errors)):
                self.layout.label(text=f"{i+1}) {surfaces_with_errors[i].name}", icon="ERROR")
        self.layout.label(text=f"Ignored objects: {len(ignored)}")
        if ignored:
            for i in range(len(ignored)):
                self.layout.label(text=f"{i+1}) {ignored[i].name}")
        self.layout.label(text=f"Animations: {len(animations)}")
        """self.layout.label(text=f"Animations: {len(animations)} ({len(animations_with_errors)} errors)")
        if animations_with_errors:
            for i in range(len(animations_with_errors)):
                self.layout.label(text=f"{i+1}) {animations_with_errors[i].state}", icon="ERROR")"""


#---
#This class represents the toolbar panel for the HGE (Haxe Game Engine) exporter in Blender. It inherits from the `HGEToolbarBase` class and the `bpy.types.Panel` class, which provides the basic functionality for a Blender UI panel.
#
#The `HGEToolbarExport` class is responsible for drawing the export-related UI elements in the Blender toolbar, such as buttons for exporting meshes and animations. It also checks the scene for any objects that can be exported and displays any errors or warnings to the user.
class HGEToolbarExport(HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_toolbar"
    bl_label = "Export"
    bl_order = 4

    def draw(self, context):
        any_objects = False
        any_errors = False
        lbl = self.layout.label
        op_both = self.layout.row()
        op_meshes = self.layout.row()
        op_anims = self.layout.row()

        for object in context.scene.objects:
            role = object.hge_obj_settings.resolve_role()
            if role:
                any_objects = True
                op_both.alert = False
                op_meshes.alert = False
                op_anims.alert = False
                if not object.hge_obj_settings.is_valid():
                    any_errors = True
                    break
        if not any_objects:
            lbl(text="There is nothing to export in the scene!", icon="ERROR")
            op_both.alert = True
            op_meshes.alert = True
            op_anims.alert = True
            print("\033[1;31;40m ATTENTION! \033[0m There is nothing to export in the scene! \033[1;31;40m No Origin empty as parent.\033[0m ")
        elif any_errors:
            self.layout.label(text="There are errors in the scene (check the Statistics tab)", icon="ERROR")

        x = op_both.operator("hge.export_dialog", text="Export",)
        x.export_meshes = True
        x.export_anims = True
        op_both.enabled = any_objects
        
        y = op_meshes.operator("hge.export_dialog", text="Export meshes",)
        y.export_meshes = True
        y.export_anims = False
        op_meshes.enabled = any_objects
        
        z = op_anims.operator("hge.export_dialog", text="Export animations",)
        z.export_meshes = False
        z.export_anims = True
        op_anims.enabled = any_objects
        
        '''op_both = self.layout.operator("hge.export_dialog", text="Export")
        op_both.export_meshes = True
        op_both.export_anims = True
        op_meshes = self.layout.operator("hge.export_dialog", text="Export meshes")
        op_meshes.export_meshes = True
        op_meshes.export_anims = False
        op_anims = self.layout.operator("hge.export_dialog", text="Export animations")
        op_anims.export_meshes = False
        op_anims.export_anims = True'''

# registration--------------------------------------------------------------------------------------------------------------------------------------------------------

#This code defines a list of Blender classes that are used for the HGE (Haxe Game Engine) Exporter addon. The classes include:
#
#- HGEObjectSettings: Settings for HGE objects
#- HGEObjectSettingsPanel: UI panel for HGE object settings
#- HGEMaterialSettings: Settings for HGE materials
#- HGERecreateShaderNodes: Utility for recreating shader nodes
#- HGEMaterialOpenMapOp: Operator for opening material maps
#- HGEMaterialPanel: UI panel for HGE materials
#- HGEMaterialMapsPanel: UI panel for HGE material maps
#- HGEMaterialRenderingPanel: UI panel for HGE material rendering settings
#- HGEMaterialSpecialPanel: UI panel for HGE material special settings
#- HGEMaterialTerrainPanel: UI panel for HGE material terrain settings
#- HGEMaterialVertexPanel: UI panel for HGE material vertex settings
#- HGEMaterialGameSpecificPanel: UI panel for HGE material game-specific settings
#- HGEMaterialAnimationsPanel: UI panel for HGE material animations
#- HGE_UL_marked_animations: UI list for marked animations
#- HGEMarkedAnimation: Representation of a marked animation
#- HGEAnimationSettings: Settings for HGE animations
#- HGEMarkAnimationOp: Operator for marking an animation
#- HGEUnmarkAnimationOp: Operator for unmarking an animation
#- HGEAnimExportProperty: Property for exporting animations
#- HGEMeshExportProperty: Property for exporting meshes
#- HGEExportOp: Operator for exporting HGE data
#- HGEOpenOutputDirOp: Operator for opening the output directory
#- HGEToolbarVersion: UI element for the HGE toolbar version
#- HGEToolbarObject: UI element for the HGE toolbar object settings
#- HGEToolbarAnimations: UI element for the HGE toolbar animations
#- HGEToolbarStatistics: UI element for the HGE toolbar statistics
#- HGEToolbarExport: UI element for the HGE toolbar export
classes = (
    HGEObjectSettings,
    HGEObjectSettingsPanel,
    # materials
    HGEMaterialSettings,
    HGERecreateShaderNodes,
    # material editor
    HGEMaterialOpenMapOp,
    HGEMaterialPanel,
    HGEMaterialMapsPanel,
    HGEMaterialRenderingPanel,
    HGEMaterialSpecialPanel,
    HGEMaterialTerrainPanel,
    HGEMaterialVertexPanel,
    HGEMaterialGameSpecificPanel,
    HGEMaterialAnimationsPanel,
    # animations
    HGE_UL_marked_animations,
    HGEMarkedAnimation,
    HGEAnimationSettings,
    HGEMarkAnimationOp,
    HGEUnmarkAnimationOp,
    # export
    HGEAnimExportProperty,
    HGEMeshExportProperty,
    HGEExportOp,
    # user interface
    HGEOpenOutputDirOp,
    HGEToolbarVersion,
    HGEToolbarObject,
    HGEToolbarAnimations,
    HGEToolbarStatistics,
    HGEToolbarExport,
)
reg_classes, unreg_classes = bpy.utils.register_classes_factory(classes)


#---
#Registers the classes defined in the `classes` list.
#This function is called to register the custom Blender classes used in the HGE Blender Exporter addon.
def register():
    reg_classes()
    bpy.types.Scene.hge_settings = bpy.props.PointerProperty(type=HGEAnimationSettings)
    bpy.types.Material.hgm_settings = bpy.props.PointerProperty(type=HGEMaterialSettings)
    bpy.types.Object.hge_obj_settings = bpy.props.PointerProperty(type=HGEObjectSettings)
    bpy.types.Object.hge_export = bpy.props.BoolProperty(name="HGE Export", default=True)


#---
#Unregisters the custom Blender classes used in the HGE Blender Exporter addon.
#
#This function is called to unregister the custom Blender classes that were registered in the `register()` function. It removes the custom properties and unregisters the classes from Blender.
def unregister():
    del bpy.types.Object.hge_export
    del bpy.types.Object.hge_obj_settings
    del bpy.types.Scene.hge_settings
    del bpy.types.Material.hgm_settings
    unreg_classes()
