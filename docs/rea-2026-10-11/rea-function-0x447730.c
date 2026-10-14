
void __fastcall FUN_004476d0(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  puStack_8 = &LAB_004929e8;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_00495dbc;
  local_4 = 0;
  if ((undefined4 *)param_1[0x38] != (undefined4 *)0x0) {
    FUN_004770e0((undefined4 *)param_1[0x38]);
    param_1[0x38] = 0;
  }
  local_4 = 0xffffffff;
  FUN_00457950(param_1);
  ExceptionList = local_c;
  return;
}

