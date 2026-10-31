% Report figures. Offline plotting only; no scope, JTAG or GUI calls.
% Compatible with MATLAB R2016a. Values are unchanged from the report.
function plot_report_figures
root=fileparts(mfilename('fullpath'));
assets=fullfile(root,'assets');
fontCN='SimSun';
blue=[0 0.4470 0.7410];
orange=[0.8500 0.3250 0.0980];
fixed=(119*(1:4)/512*100)';
adaptive=([488 484 480 476]/512*100)';
y=[fixed adaptive];
f=figure('Visible','off','Color','w','Units','inches','Position',[1 1 10 4.0666667],'Renderer','painters');
ax=axes('Parent',f,'Position',[0.09 0.20 0.88 0.67]);
b=bar(ax,1:4,y,'grouped');
set(b(1),'FaceColor',blue,'EdgeColor','none');
set(b(2),'FaceColor',orange,'EdgeColor','none');
set(ax,'FontName',fontCN,'FontSize',15,'XTick',1:4,'XLim',[0.5 4.5],...
 'YLim',[0 112],'YTick',0:25:100,'LineWidth',0.8,'Box','off',...
 'XGrid','off','YGrid','on','GridColor',[0.7 0.7 0.7],'GridAlpha',0.28,'TickDir','out');
labels=cell(1,4);
for k=1:4,labels{k}=[num2str(k) ' ' char([20010 27963 36291 31471 21475])];end
set(ax,'XTickLabel',labels);
ylabel(ax,char([24103 36733 33655 27604 20363 32 40 37 41]),'FontName',fontCN,'FontSize',15);
legend(ax,b,{char([22266 23450 22235 27133]),char([27963 36291 31471 21475 20998 37197])},...
 'Location','NorthOutside','Orientation','horizontal','Box','off','FontName',fontCN,'FontSize',15);
% Standard grouped-bar centers for two series, default BarWidth=0.8.
groupwidth=min(0.8,2/(2+1.5));
for j=1:2
 xx=(1:4)-groupwidth/2+(2*j-1)*groupwidth/4;
 for k=1:4
  text(xx(k),y(k,j)+2,sprintf('%.2f',y(k,j)),'Parent',ax,...
   'HorizontalAlignment','center','VerticalAlignment','bottom','FontName','Times New Roman','FontSize',14,'Color','k');
 end
end
set(f,'PaperUnits','inches','PaperPosition',[0 0 10 4.0666667],'PaperSize',[10 4.0666667]);
print(f,fullfile(assets,'payload_efficiency.png'),'-dpng','-r240');
savefig(f,fullfile(assets,'payload_efficiency.fig'));
close(f);

fid=fopen(fullfile(assets,'matlab_figures_verified.txt'),'w');
assert(fid>0);fprintf(fid,'MATLAB %s\n',version);
for k=1:4,fprintf(fid,'N=%d fixed=%.8f adaptive=%.8f\n',k,y(k,1),y(k,2));end
fclose(fid);
end
