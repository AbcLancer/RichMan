// ===== 4209c0 → FUN_004209c0 @ 004209c0（就是入口）  大小 99 字节

undefined4 __cdecl FUN_004209c0(undefined4 param_1,undefined4 param_2,int param_3)

{
  void *pvVar1;
  undefined4 *this;
  
  pvVar1 = *(void **)(*(int *)(param_3 + 0xc) + 0x78);
  this = FUN_00427d70(8,0,0x3ff00000);
  this[6] = 0;
  this[7] = 0x3ff00000;
  this[0x6d] = param_3;
  FUN_00428950(this,pvVar1,*(int *)(*(int *)(param_3 + 0xc) + 0x74),7);
  FUN_004289b0((int)this);
  FUN_0042f9b0((byte *)0x33,*(void **)(*(int *)(param_3 + 0xc) + 0x78));
  return 0;
}



// ===== 428950 → FUN_00428950 @ 00428950（就是入口）  大小 89 字节

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00428950(void *this,void *param_1,int param_2,undefined4 param_3)

{
  int iVar1;
  float10 fVar2;
  
  *(void **)((int)this + *(int *)((int)this + 0x20) * 4 + 0x24) = param_1;
  iVar1 = *(int *)((int)this + 0x20) + 1;
  *(int *)((int)this + 0x20) = iVar1;
  *(int *)((int)this + iVar1 * 4 + 0x24) = param_2;
  iVar1 = *(int *)((int)this + 0x20) + 1;
  *(int *)((int)this + 0x20) = iVar1;
  *(undefined4 *)((int)this + iVar1 * 4 + 0x24) = param_3;
  *(int *)((int)this + 0x20) = *(int *)((int)this + 0x20) + 1;
  fVar2 = FUN_0042bb30(param_1,param_2);
  *(float *)((int)this + *(int *)((int)this + 0x20) * 4 + 0x24) =
       (float)(fVar2 * (float10)_DAT_00495490);
  *(int *)((int)this + 0x20) = *(int *)((int)this + 0x20) + 1;
  return;
}



// ===== 4289b0 → FUN_004289b0 @ 004289b0（就是入口）  大小 74 字节

void __fastcall FUN_004289b0(int param_1)

{
  int *piVar1;
  uint *puVar2;
  int iVar3;
  int *piVar4;
  int iVar5;
  
  iVar5 = 0;
  if (0 < *(int *)(param_1 + 0x20)) {
    piVar4 = (int *)(param_1 + 0x24);
    do {
      iVar3 = *piVar4;
      piVar1 = piVar4 + 1;
      puVar2 = (uint *)(piVar4 + 2);
      iVar5 = iVar5 + 4;
      piVar4 = piVar4 + 4;
      FUN_0043cb00(DAT_004fe7ac,0x3f1,*(byte **)(iVar3 + 0xc),(byte *)(*piVar1 << 7 | *puVar2));
    } while (iVar5 < *(int *)(param_1 + 0x20));
  }
  return;
}



// ===== 42be40 → FUN_0042be40 @ 0042be40（就是入口）  大小 51 字节

void __fastcall FUN_0042be40(byte *param_1)

{
  if (*(int *)(param_1 + 0x34) != -1) {
    FUN_0043cb00(DAT_004fe7ac,0x12d,(byte *)0x0,param_1);
    FUN_00431a90(&DAT_004f2e68,*(int *)(param_1 + 0x34));
    param_1[0x34] = 0xff;
    param_1[0x35] = 0xff;
    param_1[0x36] = 0xff;
    param_1[0x37] = 0xff;
  }
  return;
}



