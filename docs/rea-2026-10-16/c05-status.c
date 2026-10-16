// ===== 435f80 → FUN_00435f80 @ 00435f80（就是入口）  大小 83 字节

void __thiscall FUN_00435f80(void *this,uint param_1,byte *param_2)

{
  int *piVar1;
  int iVar2;
  
  piVar1 = (int *)((int)this + 0x118);
  iVar2 = 0xc;
  do {
    if (*piVar1 != 0) {
      *piVar1 = 0;
    }
    piVar1 = piVar1 + 1;
    iVar2 = iVar2 + -1;
  } while (iVar2 != 0);
  *(undefined4 *)((int)this + param_1 * 4 + 0x118) = 1;
  *(byte **)((int)this + param_1 * 4 + 0x148) = param_2;
  FUN_0043cb00(DAT_004fe7ac,0x834,(byte *)(*(int *)((int)this + 0x38) << 8 | param_1),param_2);
  return;
}



