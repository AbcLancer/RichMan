
uint __thiscall FUN_00434e60(void *this,int param_1,short *param_2,void *param_3)

{
  uint uVar1;
  uint uVar2;
  short *psVar3;
  short local_100 [128];
  
  uVar1 = FUN_00434ef0(param_3,local_100,param_1);
  if (uVar1 == 0) {
    return 0;
  }
  FUN_00434c40(param_3,uVar1,local_100,0);
  FUN_0041ef20(&DAT_004e48b8,local_100,uVar1);
  FUN_00434ae0(this,uVar1,local_100,0);
  if ((param_2 != (short *)0x0) && (0 < (int)uVar1)) {
    psVar3 = local_100;
    for (uVar2 = uVar1 >> 1; uVar2 != 0; uVar2 = uVar2 - 1) {
      *(undefined4 *)param_2 = *(undefined4 *)psVar3;
      psVar3 = psVar3 + 2;
      param_2 = param_2 + 2;
    }
    for (uVar2 = (uint)((uVar1 & 1) != 0); uVar2 != 0; uVar2 = uVar2 - 1) {
      *param_2 = *psVar3;
      psVar3 = psVar3 + 1;
      param_2 = param_2 + 1;
    }
  }
  return uVar1;
}

