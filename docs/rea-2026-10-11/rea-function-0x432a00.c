
void __thiscall FUN_004329f0(void *this,int param_1)

{
  undefined4 local_4;
  
  if (*(int *)this == 0) {
    local_4 = 0xffffffff;
  }
  else {
    local_4 = *(undefined4 *)(*(int *)this + 0x38);
  }
  FUN_00402790(DAT_004a6040,(char *)&local_4,4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 4),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 8),0x10,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x18),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x1c),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x30),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x34),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x38),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x3c),4,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x40),1,param_1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0x54),0xc,param_1);
  return;
}

