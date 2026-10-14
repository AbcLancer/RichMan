
void __fastcall FUN_004361b0(void *param_1)

{
  int iVar1;
  
  if (*(int *)((int)param_1 + 0x3c) != 5) {
    FUN_00434350(param_1,-DAT_0049e960);
  }
  iVar1 = FUN_00435630(param_1,0xff);
  if (-1 < iVar1) {
    iVar1 = FUN_00433040(&DAT_004e3b18,iVar1);
    *(int *)(iVar1 + 0x3c) = *(int *)(iVar1 + 0x3c) + 1;
  }
  FUN_00436060(param_1,0,1);
  FUN_00436060(param_1,6,1);
  FUN_00436060(param_1,3,1);
  FUN_00436060(param_1,7,1);
  FUN_00436060(param_1,8,1);
  FUN_00436060(param_1,9,1);
  return;
}

