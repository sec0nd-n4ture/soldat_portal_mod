from soldat_extmod_api.mod_api import ModAPI, Event, ShaderLayer, Vector2D
from collision_disabler_area import CollisionDisabledArea
from portal import OrangePortal, BluePortal, Portal
from math import sqrt, atan2
import time
import sys

class ModMain:
    def __init__(self) -> None:
        self.api = ModAPI()
        self.api.subscribe_event(self.on_join, Event.DIRECTX_READY)
        self.api.subscribe_event(self.on_r_press, Event.R_KEY_UP)
        self.api.subscribe_event(self.on_c_press, Event.C_KEY_UP)
        self.api.subscribe_event(self.direct_input_ready, Event.DINPUT_READY)
        self.api.subscribe_event(self.direct_input_not_ready, Event.DINPUT_NOTREADY)
        self.orange_portal = None
        self.blue_portal = None
        self.portal_surface_shader = None
        self.copy_shader = None
        self.special_effects_shader = None
        self.own_player = None
        self.di_ready = False
        self.main_loop()

    def main_loop(self):
        while True:
            try:
                self.api.tick_event_dispatcher()
                if self.blue_portal:
                    self.orange_portal.tick()
                    self.blue_portal.tick()
                    if self.blue_portal.can_disable and self.orange_portal.can_disable:
                        CollisionDisabledArea.enable_collision(self.api)
                time.sleep(0.001)
            except KeyboardInterrupt:
                break
        sys.exit(1)

    def on_join(self):
        if not self.portal_surface_shader:
            CollisionDisabledArea.patch_collision(self.api)

            with open("portal_shader_fragment.glsl", "r") as f:
                shader_source_frag = f.read()

            with open("portal_shader_vertex.glsl", "r") as f:
                shader_source_vert = f.read()

            with open("area_copy_shader_fragment.glsl", "r") as f:
                shader_area_copy_frag = f.read()

            with open("special_effects_fragment.glsl", "r") as f:
                shader_special_effects_frag = f.read()

            self.own_player = self.api.get_player(self.api.get_own_id())
            self.blue_portal = BluePortal(self.api, self.own_player)
            self.orange_portal = OrangePortal(self.api, self.own_player)
            self.orange_portal.set_exit_portal(self.blue_portal)
            self.blue_portal.set_exit_portal(self.orange_portal)

            self.copy_shader = self.api.create_shader_program(
                ShaderLayer.PLAYERS, shader_area_copy_frag, shader_source_vert
            )

            self.orange_portal.enabled = True
            self.blue_portal.enabled = True

            self.copy_shader.bind_camera_pos_uniform("uCameraPos")
            self.copy_shader.enable()

            self.portal_surface_shader = self.api.create_shader_program(
                ShaderLayer.POLY, shader_source_frag, shader_source_vert
            )

            self.portal_surface_shader.bind_camera_pos_uniform("uCameraPos")
            self.portal_surface_shader.enable()

            self.portal_surface_shader.set_uniform2f("uEffectCenter1", 9999.0, 9999.0)
            self.portal_surface_shader.set_uniform2f("uEffectCenter2", 9999.0, 9999.0)

            self.orange_portal.effect_shader = self.portal_surface_shader
            self.blue_portal.effect_shader = self.portal_surface_shader

            self.special_effects_shader = self.api.create_shader_program(
                ShaderLayer.PLAYERS, shader_special_effects_frag, shader_source_vert
            )

            self.special_effects_shader.bind_camera_pos_uniform("uCameraPos")
            self.special_effects_shader.bind_time_uniform("uTime")
            self.special_effects_shader.enable()

    def on_r_press(self):
        if self.di_ready and self.portal_surface_shader:
            self.shoot_portal(self.blue_portal)
            self.copy_shader.set_uniform2f(
                "uSourceOrigin", 
                self.blue_portal.position.x, 
                self.blue_portal.position.y
            )
            self.copy_shader.set_uniform1f("uSourceRotation", self.blue_portal.rotation)

    def on_c_press(self):
        if self.di_ready and self.portal_surface_shader:
            self.shoot_portal(self.orange_portal)
            self.copy_shader.set_uniform2f(
                "uTargetOrigin", 
                self.orange_portal.position.x, 
                self.orange_portal.position.y
            )
            self.copy_shader.set_uniform1f("uTargetRotation", self.orange_portal.rotation)

    def direct_input_ready(self):
        self.di_ready = True

    def direct_input_not_ready(self):
        self.di_ready = False

    def shoot_portal(self, portal: Portal):
        cursor_pos = Vector2D(
            self.own_player.get_mouse_world_pos().x, 
            self.own_player.get_mouse_world_pos().y
        )
        player_pos = self.own_player.get_position()
        target_pos = Vector2D(player_pos.x, player_pos.y)
        shoot_direction = cursor_pos - player_pos
        shoot_direction_magnitude = sqrt(shoot_direction.x**2 + shoot_direction.y**2)
        if shoot_direction_magnitude != 0:
            shoot_direction_normalized = Vector2D(
                shoot_direction.x / shoot_direction_magnitude,
                shoot_direction.y / shoot_direction_magnitude
            )
        else:
            shoot_direction_normalized = Vector2D.zero()

        for _ in range(300):
            target_pos += Vector2D(
                shoot_direction_normalized.x * 7, 
                shoot_direction_normalized.y * 7
            )
            result = self.api.raycast(
                player_pos, 
                target_pos, 
                0, 
                9999, 
                player=True, 
                bullet=False
            )
            if result.hit_result:
                hitpoint =\
                    player_pos +\
                    Vector2D(shoot_direction_normalized.x * result.distance,
                             shoot_direction_normalized.y * result.distance)
                coltest = self.api.collision_test(
                    hitpoint + shoot_direction_normalized, 
                    False
                )
                angle = 0.0
                perp_vec = Vector2D.zero()
                if coltest:
                    angle = atan2(coltest.perp_vec.x, coltest.perp_vec.y)
                    perp_vec = coltest.perp_vec
                portal.place(hitpoint, angle, perp_vec)
                if isinstance(portal, BluePortal):
                    self.special_effects_shader.set_uniform2f(
                        "uGlowCenter1", 
                        *hitpoint.to_tuple()
                    )
                if isinstance(portal, OrangePortal):
                    self.special_effects_shader.set_uniform2f(
                        "uGlowCenter2", 
                        *hitpoint.to_tuple()
                    )
                break



if __name__ == "__main__":
    main = ModMain()
