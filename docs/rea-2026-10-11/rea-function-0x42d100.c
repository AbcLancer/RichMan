
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall FUN_0042d0d0(int param_1)

{
  int *this;
  int iVar1;
  int iVar2;
  int *piVar3;
  undefined *this_00;
  void *this_01;
  float *pfVar4;
  int iVar5;
  float *pfVar6;
  int local_a8;
  int local_a4;
  int local_a0;
  int local_98;
  int local_94;
  int local_90;
  int local_8c;
  float local_80 [16];
  int local_40 [16];
  
  this = *(int **)(DAT_0050d0d4 + 0xd0);
  FUN_00403ee0(local_80);
  iVar5 = 0;
  if (0 < DAT_004e2a80) {
    piVar3 = local_40;
    this_00 = &DAT_004e1b80;
    do {
      if ((((*(int *)(this_00 + 0x3c) == 300) ||
           (_DAT_00508fa0 <= (float)*(double *)(this_00 + 0x1c8))) ||
          (iVar2 = FUN_00435fe0(this_00,2), iVar2 != 0)) ||
         (iVar2 = FUN_00435fe0(this_00,3), iVar2 != 0)) {
        *piVar3 = 0;
      }
      else {
        *piVar3 = 1;
      }
      iVar5 = iVar5 + 1;
      this_00 = this_00 + 0x1e0;
      piVar3 = piVar3 + 1;
    } while (iVar5 < DAT_004e2a80);
  }
  local_94 = 0;
  if (0 < *(int *)(param_1 + 0x28)) {
    local_98 = 0;
    do {
      this_01 = (void *)(local_98 + *(int *)(param_1 + 0x24));
      iVar5 = 0;
      local_8c = 0;
      if (0 < *(int *)(param_1 + 0x20)) {
        piVar3 = (int *)(*(int *)(param_1 + 0x1c) + 0x20);
        do {
          if (((piVar3[2] != 0) && (*piVar3 != 0)) &&
             (*(void **)(*(int *)piVar3[1] + 0x28) == this_01)) {
            local_8c = 1;
            break;
          }
          iVar5 = iVar5 + 1;
          piVar3 = piVar3 + 0xb;
        } while (iVar5 < *(int *)(param_1 + 0x20));
      }
      local_a4 = 0;
      if (0 < *(int *)((int)this_01 + 0x50)) {
        do {
          iVar5 = *(int *)((int)this_01 + 0x4c);
          local_a0 = 0;
          if (0 < iVar5) {
            do {
              iVar5 = iVar5 * local_a4 + local_a0;
              local_a8 = local_8c;
              iVar2 = FUN_0042b1b0(this_01,iVar5);
              if ((*(int *)(iVar2 + 0x34) != 0) &&
                 (iVar1 = *(int *)(*(int *)(iVar2 + 0x34) + 0x2e0), iVar1 != 0)) {
                if (local_40[*(int *)(iVar1 + 0x38)] == 0) {
                  local_a8 = 1;
                }
                if (*(int *)(iVar2 + 0x30) == 0) {
                  local_90 = 1;
                  if ((*(byte *)(iVar2 + 0xc) & 2) != 0) goto LAB_0042d253;
                }
                else if (*(int *)(iVar2 + 0x14) == iVar5) {
                  local_90 = *(int *)(*(int *)(iVar2 + 0x30) + 0x34);
LAB_0042d253:
                  pfVar4 = (float *)((int)this_01 + 0xc);
                  pfVar6 = local_80;
                  for (iVar5 = 0x10; iVar5 != 0; iVar5 = iVar5 + -1) {
                    *pfVar6 = *pfVar4;
                    pfVar4 = pfVar4 + 1;
                    pfVar6 = pfVar6 + 1;
                  }
                  FUN_00404830(local_80,((float)local_a0 + (float)local_90 * 0.5) * 100.0,3.0,
                               ((float)local_a4 + (float)local_90 * 0.5) * 100.0);
                  FUN_00404ea0(this);
                  FUN_00404f30(this,local_80);
                  iVar5 = **(int **)(param_1 + 0x2d0 + local_90 * 4);
                  iVar2 = FUN_00440cb0(*(void **)(iVar2 + 0x34),local_a8);
                  (**(code **)(iVar5 + 8))(iVar2);
                  FUN_00404ed0((int)this);
                }
              }
              iVar5 = *(int *)((int)this_01 + 0x4c);
              local_a0 = local_a0 + 1;
            } while (local_a0 < iVar5);
          }
          local_a4 = local_a4 + 1;
        } while (local_a4 < *(int *)((int)this_01 + 0x50));
      }
      local_94 = local_94 + 1;
      local_98 = local_98 + 0x58;
    } while (local_94 < *(int *)(param_1 + 0x28));
  }
  return;
}

