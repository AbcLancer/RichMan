
void __fastcall FUN_0042eeb0(int param_1)

{
  void *this;
  float fVar1;
  int *this_00;
  int iVar2;
  int iVar3;
  float *this_01;
  float unaff_ESI;
  float *pfVar4;
  float *pfVar5;
  longlong lVar6;
  float local_c8;
  float local_c4;
  float local_c0;
  undefined4 local_bc;
  int local_b8;
  int local_b4;
  int local_b0;
  int local_ac;
  int *local_a8;
  int local_a4;
  float local_a0 [12];
  float local_70;
  float local_6c;
  float local_68;
  undefined1 auStack_64 [36];
  float local_40 [16];
  
  local_a8 = *(int **)(DAT_0050d0d4 + 0xd0);
  local_a4 = *(int *)(*(int *)(DAT_0050d0d4 + 200) + 8);
  *(undefined4 *)(local_a4 + 0x2c) = 0xff000000;
  *(undefined4 *)(local_a4 + 0x30) = 0x41a00000;
  *(undefined4 *)(local_a4 + 0x34) = 0x41a00000;
  local_c4 = 0.0;
  local_c0 = 0.0;
  local_bc = 0;
  local_ac = param_1;
  FUN_00403ee0(local_40);
  FUN_00403ee0(local_a0);
  local_b0 = 0;
  if (0 < *(int *)(param_1 + 0x18)) {
    local_b8 = 0;
    do {
      iVar3 = local_b8;
      iVar2 = FUN_0042bb50(*(int *)(param_1 + 0x14) + local_b8);
      if (((iVar2 != 0) && ((*(byte *)(iVar2 + 0xc) & 2) != 0)) && (*(int *)(iVar2 + 0x34) != 0)) {
        this = *(void **)(*(int *)(param_1 + 0x14) + 0x28 + iVar3);
        lVar6 = FUN_0042b8b0(this,*(int *)(*(int *)(param_1 + 0x14) + iVar3 + 0x2c));
        local_b4 = (int)lVar6;
        fVar1 = (float)local_b4 * 1e-05;
        if (1.0 < fVar1) {
          fVar1 = 1.0;
        }
        this_01 = (float *)((int)this + 0xc);
        pfVar4 = this_01;
        pfVar5 = local_40;
        for (iVar3 = 0x10; iVar3 != 0; iVar3 = iVar3 + -1) {
          *pfVar5 = *pfVar4;
          pfVar4 = pfVar4 + 1;
          pfVar5 = pfVar5 + 1;
        }
        FUN_004042a0(local_a0);
        local_70 = ((float)(int)*(short *)(iVar2 + 0x3c) + 0.5) * 100.0;
        local_c8 = (float)(int)*(short *)(iVar2 + 0x3e);
        local_68 = ((float)(int)local_c8 + 0.5) * 100.0;
        local_6c = fVar1 * 142.0 - 142.0;
        FUN_00403f10(local_40,local_a0);
        this_00 = local_a8;
        FUN_00404ea0(local_a8);
        FUN_00404f30(this_00,local_40);
        (**(code **)(**(int **)(local_ac + 0x2d0) + 8))(0);
        FUN_00404ed0((int)this_00);
        local_c8 = ((float)(int)*(short *)(iVar2 + 0x3c) + 0.5) * 100.0;
        local_c0 = ((float)(int)*(short *)(iVar2 + 0x3e) + 0.5) * 100.0;
        local_c4 = unaff_ESI + 50.0;
        FUN_004041c0(this_01,(int)&local_c8,1);
        FUN_00485290(auStack_64,&DAT_0049e564);
        (**(code **)(*local_a8 + 0x14))(auStack_64,local_c8,local_c4,local_c0);
        param_1 = local_ac;
        iVar3 = local_b8;
      }
      local_b0 = local_b0 + 1;
      local_b8 = iVar3 + 0x44;
    } while (local_b0 < *(int *)(param_1 + 0x18));
  }
  return;
}

