function [y, w, info] = rf47_lms_bootstrap(u, options)
%BTB_CMA Blind 2x2 complex fractionally-spaced CMA. No reference input.
L = size(u,2)/2; mid = (L+1)/2;
a = options.initialAngle;
w = complex(zeros(2*L,2)); w(mid,:)=[cos(a),sin(a)];
w(mid+L,:)=[-sin(a),cos(a)];
trainCount = min(options.trainSymbols, size(u,1));
R = 1; costs = zeros(numel(options.cmaSteps),1);
for pass=1:numel(options.cmaSteps)
    mu = options.cmaSteps(pass);
    for k=1:trainCount
        row=u(k,:); out=row*w;
        error=out.*(R-abs(out).^2);
        w=w+(mu/(sum(abs(row).^2)+1e-8))*(row'*error);
    end
    yp=u(1:trainCount,:)*w;
    costs(pass)=mean(mean((abs(yp).^2-1).^2));
end
y=u*w;
% Reject duplicate-polarization convergence in trial selection.
rho=abs(sum(conj(y(1:trainCount,1)).*y(1:trainCount,2)))/sqrt(sum(abs(y(1:trainCount,1)).^2)*sum(abs(y(1:trainCount,2)).^2));
rhoConjugate=abs(sum(y(1:trainCount,1).*y(1:trainCount,2)))/sqrt(sum(abs(y(1:trainCount,1)).^2)*sum(abs(y(1:trainCount,2)).^2));
info=struct('costs',costs,'duplicateCorrelation',max(rho,rhoConjugate),'weightNorm',sqrt(sum(abs(w).^2,1)));
end
