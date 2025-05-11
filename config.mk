VIVADO := $(XILINX_VIVADO)/bin/vivado
$(TEMP_DIR)/input.xo:
	mkdir -p $(TEMP_DIR)
	$(VIVADO) -mode batch -source scripts/gen_input_xo.tcl -tclargs $(TEMP_DIR)/input.xo input $(TARGET) $(PLATFORM) $(XSA)

$(TEMP_DIR)/adder.xo: 
	mkdir -p $(TEMP_DIR)
	$(VIVADO) -mode batch -source scripts/gen_adder_xo.tcl -tclargs $(TEMP_DIR)/adder.xo adder $(TARGET) $(PLATFORM) $(XSA)

$(TEMP_DIR)/hbm_writer.xo:
	mkdir -p $(TEMP_DIR)
	$(VIVADO) -mode batch -source scripts/gen_hbm_writer_xo.tcl -tclargs $(TEMP_DIR)/hbm_writer.xo hbm_writer $(TARGET) $(PLATFORM) $(XSA)



