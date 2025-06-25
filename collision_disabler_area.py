from soldat_extmod_api.mod_api import MEM_COMMIT, MEM_RESERVE, PAGE_EXECUTE_READWRITE, PAGE_READWRITE
from soldat_extmod_api.graphics_helper.gui_addon import DynamicRectangle
from soldat_extmod_api.graphics_helper.vector_utils import Vector2D
from soldat_extmod_api.mod_api import ModAPI, Player


class CollisionDisabledArea(DynamicRectangle):
    col_player_target_ptr = None | int
    col_state_flag_ptr = None | int
    def __init__(
            self, 
            position: Vector2D, 
            dimensions: Vector2D, 
            pivot: Vector2D, 
            api: ModAPI, 
            for_player: Player):
        super().__init__(position, dimensions, Vector2D(1, 1), 0, pivot)
        self.api = api
        self.player = None
        self.set_target_player(for_player)
        self.enabled = False
        self.debugging = False
        self.can_disable = True

    def tick(self):
        if self.enabled:
            contains = self.contains_point(self.player.get_position())
            if contains:
                CollisionDisabledArea.disable_collision(self.api)

            self.can_disable = not contains

    def set_target_player(self, player: Player):
        self.player = player
        self.api.soldat_bridge.write(
            CollisionDisabledArea.col_player_target_ptr, 
            self.player.tsprite_object_addr.to_bytes(4, "little")
        )

    def rect_set_pos(self, pos: Vector2D):
        super().rect_set_pos(pos + Vector2D(-self.dimensions.x/2, -(self.dimensions.y/2)))

    @staticmethod
    def patch_collision(api: ModAPI):
        CollisionDisabledArea.col_player_target_ptr = api.soldat_bridge.allocate_memory(
            8, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE
        )
        CollisionDisabledArea.col_state_flag_ptr = CollisionDisabledArea.col_player_target_ptr+4
        api.assembler.add_to_symbol_table({
            "target_player": CollisionDisabledArea.col_player_target_ptr,
            "collision_state_flag": CollisionDisabledArea.col_state_flag_ptr
        })
        patch_code1 = f"""
        push eax
        mov al, byte ptr ds:[collision_state_flag]
        test al, al
        pop eax
        jz exit_no_action
        cmp eax, dword ptr ds:[target_player]
        je early_exit
        exit_no_action:
            mov dword ptr ss:[ebp-0x04], edx
            mov ebx, eax
            jmp 0x0058756E
        early_exit:
            xor al, al
            jmp 0x005882D4
        """
        col_disable_patch_addr = api.soldat_bridge.allocate_memory(
            len(api.assembler.assemble(patch_code1, 0)), 
            MEM_COMMIT | MEM_RESERVE,
            PAGE_EXECUTE_READWRITE
        )
        api.soldat_bridge.write(
            col_disable_patch_addr,
            api.assembler.assemble(patch_code1, col_disable_patch_addr)
        )

        api.soldat_bridge.write(
            0x00587569, 
            api.assembler.assemble(f"jmp {hex(col_disable_patch_addr)}", 0x00587569)
        )


        patch_code2 = f"""
        push eax
        mov al, byte ptr ds:[collision_state_flag]
        test al, al
        pop eax
        jz exit_no_action
        cmp eax, dword ptr ds:[target_player]
        je early_exit
        exit_no_action:
            mov byte ptr ss:[ebp-0x01], dl
            mov edi, eax
            jmp 0x00587192
        early_exit:
            xor al, al
            jmp 0x0058754E
        """

        col_disable_patch_addr2 = api.soldat_bridge.allocate_memory(
            len(api.assembler.assemble(patch_code2, 0)), 
            MEM_COMMIT | MEM_RESERVE,
            PAGE_EXECUTE_READWRITE
        )
        api.soldat_bridge.write(
            col_disable_patch_addr2,
            api.assembler.assemble(patch_code2, col_disable_patch_addr2)
        )

        api.soldat_bridge.write(
            0x0058718D, 
            api.assembler.assemble(f"jmp {hex(col_disable_patch_addr2)}", 0x0058718D)
        )

    @staticmethod
    def disable_collision(api: ModAPI):
        CollisionDisabledArea.set_collision_state(api, True)

    @staticmethod
    def enable_collision(api: ModAPI):
        CollisionDisabledArea.set_collision_state(api, False)        

    @staticmethod
    def set_collision_state(api: ModAPI, state: bool):
        api.soldat_bridge.write(
            CollisionDisabledArea.col_state_flag_ptr,
            state.to_bytes()
        )
