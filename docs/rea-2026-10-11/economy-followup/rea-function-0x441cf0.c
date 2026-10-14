
undefined4
FUN_00441cf0(int param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4,undefined4 param_5
            ,undefined4 param_6,undefined4 param_7,undefined4 param_8,undefined4 param_9)

{
  void *pvVar1;
  undefined4 *puVar2;
  void *this;
  int iVar3;
  undefined4 uStack00000058;
  undefined4 uStack0000006c;
  void *in_stack_00005e64;
  void *in_stack_00005e78;
  void *in_stack_00005e7c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0049277e;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  FUN_004854d0();
  *(undefined4 *)((int)this + 0x18) = 0;
  FUN_00401bd0(this,0x96,0x78);
  FUN_00442190(this,in_stack_00005e7c);
  FUN_00442700((int)this);
  FUN_004026c0(DAT_004a6040,(char *)&param_2,4,(int)in_stack_00005e78);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x1c),4,(int)in_stack_00005e78);
  iVar3 = *(int *)((int)this + 0x1c);
  if (iVar3 == 0) {
    *(undefined4 *)((int)this + 0x20) = 0;
  }
  else {
    pvVar1 = _malloc(iVar3 * 4);
    *(void **)((int)this + 0x20) = pvVar1;
  }
  puVar2 = (undefined4 *)&stack0x000053e0;
  param_1 = 8;
  do {
    FUN_00403ee0(puVar2);
    puVar2 = puVar2 + 0x11;
    param_1 = param_1 + -1;
  } while (param_1 != 0);
  FUN_004778e0(&param_3,s_gfxscript_terrgeom_gbf_0049cb8c);
  iVar3 = 0;
  if (0 < *(int *)((int)this + 0x1c)) {
    do {
      pvVar1 = (void *)(**(code **)(*DAT_0050d0d4 + 8))();
      FUN_0040a050(pvVar1,in_stack_00005e78,(int)&param_3);
      FUN_00406d50(pvVar1,1,*(int *)((int)this + 0x11a28));
      puVar2 = operator_new(0xd8);
      if (puVar2 == (undefined4 *)0x0) {
        puVar2 = (undefined4 *)0x0;
      }
      else {
        puVar2 = FUN_004075d0(puVar2);
      }
      *(undefined4 **)(*(int *)((int)this + 0x20) + iVar3 * 4) = puVar2;
      *(void **)(*(int *)(*(int *)((int)this + 0x20) + iVar3 * 4) + 0xd0) = pvVar1;
      iVar3 = iVar3 + 1;
    } while (iVar3 < *(int *)((int)this + 0x1c));
  }
  FUN_00441b20(this,in_stack_00005e78);
  FUN_00476dd0(&param_3,2);
  param_7 = 1;
  param_8 = 0xf;
  param_9 = 0xf;
  param_5 = 0;
  param_3 = 0;
  uStack00000058 = 2;
  uStack0000006c = 2;
  pvVar1 = FUN_004777d0((void *)DAT_0050d0d4[0x30],&param_3);
  *(void **)((int)this + 0x11974) = pvVar1;
  pvVar1 = (void *)(**(code **)(*DAT_0050d0d4 + 4))();
  *(void **)((int)this + 0x11978) = pvVar1;
  FUN_00479f30(pvVar1,1);
  *(undefined4 *)((int)this + 0x1198c) = 0;
  *(undefined4 *)((int)this + 0x11990) = 0;
  *(undefined4 *)((int)this + 0x11994) = 0;
  *(undefined4 *)((int)this + 0x11998) = 0x3f800000;
  *(undefined4 *)((int)this + 0x1197c) = 0;
  *(undefined4 *)((int)this + 0x11980) = 0;
  *(undefined4 *)((int)this + 0x11984) = 0;
  *(undefined4 *)((int)this + 0x11988) = 0x3f800000;
  *(undefined4 *)((int)this + 0x1199c) = 0;
  *(undefined4 *)((int)this + 0x119a0) = 0;
  *(undefined4 *)((int)this + 0x119a4) = 0;
  *(undefined4 *)((int)this + 0x119a8) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119ac) = 0x3e4ccccd;
  *(undefined4 *)((int)this + 0x119b0) = 0x3e4ccccd;
  *(undefined4 *)((int)this + 0x119b4) = 0x3e4ccccd;
  *(undefined4 *)((int)this + 0x119b8) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119bc) = 0;
  *(undefined4 *)((int)this + 0x119d4) = 0;
  *(undefined4 *)((int)this + 0x119d8) = 0;
  *(undefined4 *)((int)this + 0x119dc) = 0;
  *(undefined4 *)((int)this + 0x119e0) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119c4) = 0;
  *(undefined4 *)((int)this + 0x119c8) = 0;
  *(undefined4 *)((int)this + 0x119cc) = 0;
  *(undefined4 *)((int)this + 0x119d0) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119e4) = 0x3f4ccccd;
  *(undefined4 *)((int)this + 0x119e8) = 0x3ecccccd;
  *(undefined4 *)((int)this + 0x119ec) = 0;
  *(undefined4 *)((int)this + 0x119f0) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119f4) = 0x3f800000;
  *(undefined4 *)((int)this + 0x119f8) = 0;
  *(undefined4 *)((int)this + 0x119fc) = 0;
  *(undefined4 *)((int)this + 0x11a04) = 0;
  *(undefined4 *)((int)this + 0x11a00) = 0x3f800000;
  ExceptionList = in_stack_00005e64;
  return 1;
}

