
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00442d00(void *this,undefined4 param_1,undefined4 param_2)

{
  float fVar1;
  double dVar2;
  void *this_00;
  int iVar3;
  int *piVar4;
  int iVar5;
  undefined4 *puVar6;
  int iVar7;
  int local_c10;
  int *local_c0c;
  int *local_c08;
  undefined4 *local_c04;
  int local_c00 [256];
  int local_800 [256];
  undefined4 local_400 [256];
  
  iVar5 = 0;
  if (0 < *(int *)((int)this + 0x24)) {
    iVar7 = 0;
    do {
      FUN_00441b00((int *)(iVar7 + *(int *)((int)this + 0x28)));
      iVar5 = iVar5 + 1;
      iVar7 = iVar7 + 0xc;
    } while (iVar5 < *(int *)((int)this + 0x24));
  }
  iVar7 = 0;
  iVar5 = 0;
  local_c10 = 0;
  this_00 = (void *)FUN_00401cf0((int)this);
  if (this_00 != (void *)0x0) {
    local_c0c = local_800;
    local_c08 = local_c00;
    local_c04 = local_400;
    do {
      if (*(float *)((int)this_00 + 0x6c) <= 0.0) {
LAB_00442dbd:
        if ((*(byte *)((int)this_00 + 0x50) & 6) != 0) {
          *(double *)((int)this_00 + 0x60) =
               (double)CONCAT44(param_2,param_1) + *(double *)((int)this_00 + 0x60);
          if (((*(byte *)((int)this_00 + 0x50) & 2) != 0) &&
             (1.5 < *(double *)((int)this_00 + 0x60))) {
            FUN_00443360(this_00,2);
          }
          if (((*(byte *)((int)this_00 + 0x50) & 4) != 0) &&
             (2.0 < *(double *)((int)this_00 + 0x60))) {
            FUN_00443360(this_00,4);
          }
        }
        if (((*(int *)((int)this_00 + 0x54) == 0) && ((*(byte *)((int)this_00 + 0x50) & 8) != 0)) &&
           (dVar2 = (double)CONCAT44(param_2,param_1) + *(double *)((int)this_00 + 0x58),
           *(double *)((int)this_00 + 0x58) = dVar2, 1.5 <= dVar2)) {
          FUN_00443360(this_00,8);
        }
        if (*(int *)((int)this_00 + 0x68) == 0) {
          iVar3 = 0;
          if (0 < iVar5) {
            piVar4 = local_800;
            do {
              if (*piVar4 == *(int *)((int)this_00 + 0x48)) break;
              iVar3 = iVar3 + 1;
              piVar4 = piVar4 + 1;
            } while (iVar3 < iVar5);
          }
          if (iVar3 == iVar5) {
            *local_c0c = *(int *)((int)this_00 + 0x48);
            iVar5 = iVar5 + 1;
            local_c0c = local_c0c + 1;
          }
        }
        else {
          iVar3 = 0;
          if (0 < iVar7) {
            piVar4 = local_c00;
            do {
              if (*piVar4 == *(int *)((int)this_00 + 0x48)) break;
              iVar3 = iVar3 + 1;
              piVar4 = piVar4 + 1;
            } while (iVar3 < iVar7);
          }
          if (iVar3 == iVar7) {
            *local_c08 = *(int *)((int)this_00 + 0x48);
            iVar7 = iVar7 + 1;
            local_c08 = local_c08 + 1;
          }
        }
      }
      else {
        fVar1 = *(float *)((int)this_00 + 0x6c) - (float)(double)CONCAT44(param_2,param_1);
        *(float *)((int)this_00 + 0x6c) = fVar1;
        if (fVar1 <= 0.0) {
          if (*(int *)((int)this_00 + 0x70) != 0) {
            local_c10 = local_c10 + 1;
            *local_c04 = this_00;
            local_c04 = local_c04 + 1;
          }
          *(undefined4 *)((int)this_00 + 0x6c) = 0;
          goto LAB_00442dbd;
        }
        if (*(int *)((int)this_00 + 0x70) != 0) goto LAB_00442dbd;
      }
      this_00 = (void *)FUN_00401d00((int)this);
    } while (this_00 != (void *)0x0);
  }
  if (0 < iVar7) {
    piVar4 = local_c00;
    do {
      FUN_00406350((undefined4 *)*piVar4);
      piVar4 = piVar4 + 1;
      iVar7 = iVar7 + -1;
    } while (iVar7 != 0);
  }
  if (0 < iVar5) {
    piVar4 = local_800;
    do {
      (**(code **)(*(int *)*piVar4 + 0xc))();
      piVar4 = piVar4 + 1;
      iVar5 = iVar5 + -1;
    } while (iVar5 != 0);
  }
  if (0 < local_c10) {
    puVar6 = local_400;
    do {
      FUN_00443010(this,(int *)*puVar6,0.0);
      puVar6 = puVar6 + 1;
      local_c10 = local_c10 + -1;
    } while (local_c10 != 0);
  }
  _DAT_0049eea0 = _DAT_0049eea0 - (double)CONCAT44(param_2,param_1) * 0.2;
  if (_DAT_0049eea0 < 0.0) {
    _DAT_0049eea0 = 1.0;
  }
  FUN_00442810(this,(double)CONCAT44(param_2,param_1));
  if (*(int *)((int)this + 0x11a2c) == 0) {
    FUN_00442460((int)this);
  }
  return;
}

