
void __thiscall FUN_004338c0(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  void *local_4;
  
  iVar1 = param_1;
  local_4 = this;
  FUN_00423830(*(void **)((int)this + 0xc),param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x34),4,iVar1);
  param_1 = *(int *)((int)this + 0x3c);
  iVar2 = FUN_00433a60(param_1,DAT_004e1b1c);
  if (iVar2 == 0) {
    param_1 = 0;
  }
  FUN_00402790(DAT_004a6040,(char *)&param_1,4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x40),0x40,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x80),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x84),0x8c,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x110),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x114),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x118),0x30,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x148),0x30,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x178),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x17c),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x180),0x10,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x19c),0x20,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x1c8),8,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x1d0),8,iVar1);
  if (*(int *)((int)this + 0x1c0) == 0) {
    local_4 = (void *)0xffffffff;
  }
  else {
    local_4 = *(void **)(*(int *)((int)this + 0x1c0) + 0x44);
  }
  FUN_00402790(DAT_004a6040,(char *)&local_4,4,iVar1);
  return;
}

