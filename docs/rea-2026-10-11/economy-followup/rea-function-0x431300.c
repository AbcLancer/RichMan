
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

bool __cdecl FUN_00431300(undefined4 param_1,void *param_2)

{
  bool bVar1;
  int iVar2;
  
  bVar1 = FUN_00431340(param_2);
  iVar2 = FUN_00435fe0(param_2,1);
  if (iVar2 == 0) {
    _DAT_004fdb20 = param_2;
    FUN_0042ab30(&DAT_005090b0,0x4c,(int *)&DAT_004fdb20);
  }
  return bVar1;
}

