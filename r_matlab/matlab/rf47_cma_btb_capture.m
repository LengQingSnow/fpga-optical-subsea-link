function [capture,reference] = rf47_cma_btb_capture(host,port)
%RF47_CMA_BTB_CAPTURE Single acquisition with read-only replay identity guards.
clock=tic; before=rf47_cma_btb_reference(); beforeSeconds=toc(clock);
clock=tic;
capture=rf47_lms_btb_scope_read(host,port,1000000);
scopeSeconds=toc(clock); clock=tic;
reference=rf47_cma_btb_reference();
capture.transferTimingSeconds=[beforeSeconds scopeSeconds toc(clock)];
assert(isequal(before.signature,reference.signature) && ...
    isequal(before.dwords,reference.dwords), ...
    'RF47 configuration changed during capture; this record is not counted');
end
