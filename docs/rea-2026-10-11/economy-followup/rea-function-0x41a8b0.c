
void __thiscall FUN_0041a7c0(void *this,char *param_1,uint param_2,int param_3)

{
  int iVar1;
  uint *puVar2;
  
  iVar1 = FUN_0047e960(DAT_00508d24,2);
  puVar2 = FUN_00402430(DAT_004a6040,s_server_data_0049d324,0x202);
  FUN_00402790(DAT_004a6040,param_1,param_2,(int)puVar2);
  FUN_00402900(DAT_004a6040,(int)puVar2,0,1);
  DAT_004e1b1c = 0;
  if (param_3 == 0) {
    FUN_004026c0(DAT_004a6040,(char *)((int)this + 0xc),4,(int)puVar2);
    FUN_0047ec10(&DAT_004f2a48,(uint)puVar2);
  }
  else {
    FUN_0041a930(&DAT_004e3b28,(int)puVar2);
    FUN_0041c1a0(&DAT_004f2a38,(int)puVar2);
    FUN_0041ea80(&DAT_004e48b8,(int)puVar2);
    FUN_00437f10(&DAT_004f1b08,(int)puVar2);
    FUN_00433150(&DAT_004e3b18,(int)puVar2);
    FUN_00440f70(&DAT_004e3b48,(int)puVar2);
    FUN_00431bf0(&DAT_004f2e68,(int)puVar2);
    FUN_0042cba0(&DAT_004e3820,(int)puVar2);
    FUN_00429800(&DAT_004e3b80,(int)puVar2);
  }
  FUN_00402660(DAT_004a6040,puVar2);
  FUN_0047e960(DAT_00508d24,iVar1);
  return;
}

