
void __fastcall FUN_0044d6c0(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  puStack_8 = &LAB_00492d08;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_00495fd4;
  local_4 = 0;
  if ((undefined4 *)param_1[0x47] != (undefined4 *)0x0) {
    FUN_004770e0((undefined4 *)param_1[0x47]);
    param_1[0x47] = 0;
  }
  if ((undefined4 *)param_1[0x46] != (undefined4 *)0x0) {
    FUN_004770e0((undefined4 *)param_1[0x46]);
    param_1[0x46] = 0;
  }
  local_4 = 0xffffffff;
  FUN_00457950(param_1);
  ExceptionList = local_c;
  return;
}

