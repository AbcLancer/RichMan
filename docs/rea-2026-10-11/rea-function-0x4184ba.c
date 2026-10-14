
void __fastcall FUN_00418480(int param_1)

{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  longlong lVar4;
  
  if (0.0 <= *(float *)(param_1 + 0x28)) {
    FUN_004182b0(param_1);
    if (*(int *)(param_1 + 0x3c) != 0) {
      lVar4 = __ftol();
      uVar1 = (uint)lVar4 & 0x80000003;
      if ((int)uVar1 < 0) {
        uVar1 = (uVar1 - 1 | 0xfffffffc) + 1;
      }
      iVar2 = FUN_00432460(uVar1);
      FUN_004144f0(DAT_004c2344,iVar2);
      puVar3 = (undefined4 *)FUN_00414510(DAT_004c2344,0);
      *puVar3 = *(undefined4 *)(param_1 + 0x1c);
      puVar3[1] = *(undefined4 *)(param_1 + 0x20);
      puVar3[2] = *(undefined4 *)(param_1 + 0x24);
      puVar3[1] = *(float *)(param_1 + 0x34) + (float)puVar3[1];
      puVar3[3] = *(undefined4 *)(param_1 + 0x30);
      puVar3[4] = *(undefined4 *)(param_1 + 0x34);
      (**(code **)(*DAT_004c2344 + 0x14))();
    }
  }
  return;
}

