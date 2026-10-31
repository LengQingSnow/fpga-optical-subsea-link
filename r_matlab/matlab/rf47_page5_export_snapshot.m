function rf47_page5_export_snapshot()
% Temporary read-only GUI snapshot for the user's requested export.
target=smf_project_path('r_matlab','tests_page5_cma_cd_20260922','export_work','gui_snapshot_20plus.mat');
if exist(target,'file'),return;end
figs=findall(0,'Type','figure');
for k=1:numel(figs)
 g=guidata(figs(k));
 if ~isstruct(g) || ~isfield(g,'dispersionCmaBerHistory'),continue;end
 selectedTitle=get(get(g.tabs,'SelectedTab'),'Title');
 if isequal(get(g.tabs,'SelectedTab'),g.cma_tab)
  history=g.cmaBerHistory;result=g.cmaResult;last=g.cmaLastBer;
 else
  history=g.dispersionCmaBerHistory;result=g.dispersionCmaResult;last=g.dispersionCmaLastBer;
 end
 if isempty(history) || numel(history.time)<20 || isempty(result),continue;end
 savedAt=now;source='Live GUI guidata; full retained history of selected constellation page';
 save(target,'history','result','last','savedAt','source','selectedTitle');
 fprintf('GUI EXPORT SNAPSHOT: %d windows, %s to %s\n',numel(history.time),datestr(history.time(1),31),datestr(history.time(end),31));
 return;
end
error('export:NotReady','Select the constellation/BER page with at least 20 windows and a valid constellation, then run this export again.');
end
