from soldat_extmod_api.graphics_helper.gui_addon import DynamicRectangle
from soldat_extmod_api.graphics_helper.vector_utils import Vector2D
from soldat_extmod_api.mod_api import ModAPI, Player, ShaderProgram
from soldat_extmod_api.graphics_helper.math_utils import lerpf
from collision_disabler_area import CollisionDisabledArea
import math



PORTAL_MAX_REUSE_DELAY = 0.35
PORTAL_DIMENSIONS = Vector2D(45, 50)
PORTAL_PIVOT = Vector2D(PORTAL_DIMENSIONS.x / 2, PORTAL_DIMENSIONS.y / 2)
GAME_DIMENSIONS_HALF = Vector2D(426.5, 240)

class Portal(CollisionDisabledArea):
    def __init__(self, api: ModAPI, linked_player: Player):
        super().__init__(Vector2D.zero(), PORTAL_DIMENSIONS, PORTAL_PIVOT, api, linked_player)
        self.exit_portal : Portal = None
        self.teleport_position = Vector2D.zero()
        self.radius_target = 19.0
        self.radius_current = 19.0
        self.effect_shader : ShaderProgram = None
        self.effect_position_uniform_name = ""
        self.effect_radius_uniform_name = ""
        self.exit_position = None
        self.perp_vec = None
        self.teleport_area_rect = DynamicRectangle(
            Vector2D.zero(),
            Vector2D(self.dimensions.x, self.dimensions.y / 2),
            self.scale,
            0,
            Vector2D(self.dimensions.x / 2, self.dimensions.y / 4)
        )
        self.inside_state = False

    def set_exit_portal(self, portal):
        self.exit_portal = portal

    def place(self, position: Vector2D, angle: float, perp_vec: Vector2D):
        self.effect_shader.set_uniform1f(self.effect_radius_uniform_name, 0.0)
        self.effect_shader.set_uniform2f(self.effect_position_uniform_name, *position.to_tuple())
        self.radius_current = 0.0
        self.set_rotation(angle)
        self.rect_set_pos(position)
        self.teleport_area_rect.set_rotation(angle)
        self.teleport_area_rect.rect_set_pos(
            self.get_exit_point()
            +
            Vector2D(
                -self.teleport_area_rect.dimensions.x/2, 
                -(self.teleport_area_rect.dimensions.y/2 - 10)
            )
        )
        self.teleport_position = self.get_tp_point()
        self.perp_vec = perp_vec

    def tick(self):
        super().tick()
        if round(self.radius_current + 0.1) != self.radius_target:
            radius_curr = lerpf(self.radius_current, self.radius_target, 0.1)
            self.radius_current = radius_curr
            if self.effect_shader:
                self.effect_shader.set_uniform1f(
                    self.effect_radius_uniform_name,
                    radius_curr
                )
        if self.is_whole_player_inside():
            if not self.inside_state and self.exit_portal.perp_vec:
                self.inside_state = True
                self.player.set_position(self.exit_portal.teleport_position)
                velocity = self.player.get_velocity()
                speed = math.sqrt(velocity.x**2 + velocity.y**2) + 0.3
                perp_vec = self.exit_portal.perp_vec
                perp_vec_magnitude = math.sqrt(perp_vec.x**2 + perp_vec.y**2)
                if perp_vec_magnitude != 0:
                    perp_vec_normalized = Vector2D(
                        perp_vec.x / perp_vec_magnitude,
                        perp_vec.y / perp_vec_magnitude
                    )
                else:
                    perp_vec_normalized = Vector2D(0, 0)

                self.player.set_velocity(
                    -Vector2D(
                        perp_vec_normalized.x * speed, 
                        perp_vec_normalized.y * speed
                    )
                )
        else:
            self.inside_state = False



    def get_exit_point(self) -> Vector2D:
        half_height = (self.dimensions.y * self.scale.x) / 2
        local_exit = Vector2D(0, half_height - 4)
        cos_r = math.cos(self.rotation)
        sin_r = math.sin(self.rotation)
        rotated_exit = Vector2D(
            local_exit.x * cos_r - local_exit.y * sin_r,
            local_exit.x * sin_r - local_exit.y * cos_r
        )
        return self.pivot - rotated_exit

    def get_tp_point(self) -> Vector2D:
        local_exit = Vector2D(0, -6)
        cos_r = math.cos(self.rotation)
        sin_r = math.sin(self.rotation)
        rotated_exit = Vector2D(
            local_exit.x * cos_r - local_exit.y * sin_r,
            local_exit.x * sin_r - local_exit.y * cos_r
        )
        return self.pivot - rotated_exit

    def is_whole_player_inside(self) -> bool:
        player_pos = self.player.get_position()
        return self.contains_point(player_pos) and self.teleport_area_rect.contains_point(player_pos)


class BluePortal(Portal):
    def __init__(self, api: ModAPI, linked_player: Player):
        super().__init__(api, linked_player)
        self.effect_position_uniform_name = "uEffectCenter1"
        self.effect_radius_uniform_name = "uEffectRadius1"

class OrangePortal(Portal):
    def __init__(self, api: ModAPI, linked_player: Player):
        super().__init__(api, linked_player)
        self.effect_position_uniform_name = "uEffectCenter2"
        self.effect_radius_uniform_name = "uEffectRadius2"
