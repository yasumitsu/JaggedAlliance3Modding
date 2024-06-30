import os
import re
import subprocess
import threading
import bpy
import bpy_extras

# settings--------------------------------------------------------------------------------------------------------------------------------------------------------

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

class EntityName:
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


def prop_exists(object, prop):
    return prop in {
        *object.keys(),
        *type(object).bl_rna.properties.keys(),
    }


def is_attach(name):
    return len(name) > 2 and name.startswith("-")


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

surface_collider_flag_props = [
    "surface_collider_flag_T",
    "surface_collider_flag_P",
    "surface_collider_flag_V",
    "surface_collider_flag_S",
    "surface_collider_flag_A",
    "surface_collider_flag_I",
]
def update_surf_collider_flags(settings: "HGEObjectSettings", context):
    if not any(getattr(settings, prop) for prop in surface_collider_flag_props):
        settings.surface_collider_flag_P = True
        settings.surface_collider_flag_V = True
        settings.surface_collider_flag_S = True

def update_inherit_animation(settings: "HGEObjectSettings", context):
    if settings.inherit_animation != "None":
        settings.state = "_mesh"
    else:
        settings.state = "idle"

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

def inherit_anim_items_callback(self, context):
    return INHERIT_ANIM_ITEMS.get(SETTINGS["game"], (("None", "None", "no inheritance", 0),))

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


class HGEObjectSettingsPanel(HGEObjectSettingsPanelBase, bpy.types.Panel):
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "object"
    bl_idname = "HGE_PT_object_settings"
    bl_label = "Haemimont Object"

# materials--------------------------------------------------------------------------------------------------------------------------------------------------------

class MaterialPropDef:
    def __init__(self, id, default, settings_name, map=False):
        self.id = id
        self.default = default
        self.settings_name = settings_name
        self.map = map


# these are the properties that will be visible by the AssetsProcessor
# they are assigned as "custom properties" of the materials
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


def remove_material_props(material):
    for prop in MATERIAL_PROPERTIES:
        if prop_exists(material, prop.id):
            del material[prop.id]


def add_material_props(material):
    for prop in MATERIAL_PROPERTIES:
        if not prop_exists(material, prop.id):
            material[prop.id] = prop.default


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


class HGEMaterialPanelBase():
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "material"
    bl_options = {"DEFAULT_CLOSED"}

    def draw_section_heading(self, text):
        row = self.layout.row()
        row.alignment = "CENTER"
        row.label(text=text)


class HGEMaterialPanel(HGEMaterialPanelBase, bpy.types.Panel):
    bl_idname = "HGE_PT_material"
    bl_label = "Haemimont Material"

    @classmethod
    def poll(cls, context):
        return context.object and context.object.active_material

    def draw(self, context):
        pass


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

class HGE_UL_marked_animations(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index, flt_flag):
        anim_name = AnimationName.parse(item.prop_name)
        row = layout.row()
        row.label(text=f"{anim_name.entity}")
        row.label(text=f"{anim_name.mesh}", icon="MESH_DATA")
        row.label(text=f"{anim_name.state}", icon="ARMATURE_DATA")


def update_marked_anim_props(marked_anim, context):
    marked_anim.armature_object[marked_anim.prop_name] = marked_anim.get_anim_prop_value()


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

class HGEAnimExportProperty(bpy.types.PropertyGroup):
    label: bpy.props.StringProperty(name="Animation Name")
    armature: bpy.props.StringProperty(name="Armature Name")
    property: bpy.props.StringProperty(name="Property Name")
    export: bpy.props.BoolProperty(
        name="Export",
        description="If this animation should be exported",
        default=True)


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

class HGEToolbarBase:
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "HGE Tools"

class HGEOpenOutputDirOp(bpy.types.Operator):
    bl_idname = "hge.open_output_dir"
    bl_label = "Open output directory"
    bl_description = "Opens output directory for exports"

    def execute(self, context):
        dir = os.path.join(os.getenv("APPDATA"), SETTINGS["appid"], "ExportedEntities")
        bpy.ops.wm.path_open(filepath=dir)
        return {"FINISHED"}


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


class HGEToolbarObject(HGEObjectSettingsPanelBase, HGEToolbarBase, bpy.types.Panel):
    bl_idname = "HGE_PT_object_settings_asdf"
    bl_label = "Object"
    bl_order = 1


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


def register():
    reg_classes()
    bpy.types.Scene.hge_settings = bpy.props.PointerProperty(type=HGEAnimationSettings)
    bpy.types.Material.hgm_settings = bpy.props.PointerProperty(type=HGEMaterialSettings)
    bpy.types.Object.hge_obj_settings = bpy.props.PointerProperty(type=HGEObjectSettings)
    bpy.types.Object.hge_export = bpy.props.BoolProperty(name="HGE Export", default=True)


def unregister():
    del bpy.types.Object.hge_export
    del bpy.types.Object.hge_obj_settings
    del bpy.types.Scene.hge_settings
    del bpy.types.Material.hgm_settings
    unreg_classes()
