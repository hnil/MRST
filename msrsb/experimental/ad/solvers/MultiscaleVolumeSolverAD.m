classdef MultiscaleVolumeSolverAD < LinearSolverAD
    % Multiscale linear solver
   properties
       prolongationType
       controlVolumeRestriction
       updateBasis
       resetBasis
       basis
       localSolver
       coarsegrid
       setupTime
       useMEX
       mexGrid
       basisIterations
       basisTolerance
       
       getSmoother
       useGMRES
   end
   methods
       function solver = MultiscaleVolumeSolverAD(coarsegrid, varargin)
           solver = solver@LinearSolverAD();
           
           Nf = coarsegrid.parent.cells.num;
           Nc = coarsegrid.cells.num;
           dim = coarsegrid.parent.griddim;
           
           % Default options
           solver.prolongationType = 'smoothed';
           solver.controlVolumeRestriction = true;
           solver.updateBasis = false;
           solver.maxIterations = 0;
           solver.getSmoother = [];
           solver.useGMRES = false;
           solver.basisTolerance = 5e-3;
           solver.useMEX = true;
           solver.mexGrid = [];
           solver.resetBasis = false;
           solver.basisIterations = ceil(50*(Nf/Nc).^(1/dim));
           
           solver = merge_options(solver, varargin{:});
           
           solver.setupTime = 0;
           solver.coarsegrid = coarsegrid;
       end
       
       function [x, report] = solveLinearSystem(solver, A, b)
           CG = solver.coarsegrid;
           nc = CG.parent.cells.num;
           if isempty(solver.basis)
              solver.setupSolver(A(1:nc, 1:nc), b(1:nc));
           end
           
           [x, report] = solveMultiscaleIteratively(A, b, [], ...
                                                          solver.basis, ...
                                                          solver.getSmoother, ...
                                                          solver.tolerance,...
                                                          solver.maxIterations, ...
                                                          @(A, b) mldivide(A, b), ...
                                                          solver.useGMRES, ...
                                                          solver.verbose);
       end
              
       function solver = setupSolver(solver, A, b, varargin) %#ok 
           % Run setup on a solver for a given system
           solver = solver.createBasis(A);
       end
       
       function  solver = cleanupSolver(solver, A, b, varargin) %#ok 
           % Clean up solver after use (if needed)
       end
       
       function [dx, result, report] = solveLinearProblem(solver, problem0, model)
           % Solve a linearized problem
           skipElim = isa(problem0, 'PressureReducedLinearSystem');
           if skipElim
               problem = problem0;
           else
               [problem, eliminated] = problem0.reduceToSingleVariableType('cell');
           end
           problem = problem.assembleSystem();
           [A, b]= problem.getLinearSystem;
           
           nc = solver.coarsegrid.parent.cells.num;
           doReduce = size(b, 1) > nc;
           if doReduce
               [A, b, B, C, D, E, f, h] = reduceSystem(A, b, nc);
           end
           if problem.iterationNo == 1 
               if solver.resetBasis
                  solver.basis = [];
               elseif solver.updateBasis
                   solver = solver.createBasis(A);
               end
           end
           
           timer = tic();
           [result, report] = solver.solveLinearSystem(A, b);
           if doReduce
               s = E\(h - D*result);
               result = [result; s];
           end
           
           [result, report] = problem.processResultAfterSolve(result, report);
           report.SolverTime = toc(timer);
           
           dxCell = solver.storeIncrements(problem, result);
           if skipElim
               dx = dxCell;
           else
               dx = problem.recoverFromSingleVariableType(problem0, dxCell, eliminated);
           end
       end

       function solver = createBasis(solver, A)
           if isempty(solver.basis) || solver.updateBasis
               if solver.verbose
                   fprintf('Constructing multiscale basis of type %s', solver.prolongationType)
                   if solver.controlVolumeRestriction
                       fprintf(' with control volume (CV) restriction.\n');
                   else
                       fprintf(' with Galerkin (FE) restriction.\n');
                   end
               end
               timer = tic();
               [ii, jj, vv] = find(A);
               keep = ii ~= jj;
               n = size(A, 1);
               
               
               ii = ii(keep);
               jj = jj(keep);
               vv = vv(keep);
               vv = abs(vv);
               
               dd = accumarray(jj, vv);
               
               ii = [ii; (1:n)'];
               jj = [jj; (1:n)'];
               vv = [vv; -dd];
               
               A = sparse(ii, jj, vv, n, n);
               
               [solver.basis, solver.coarsegrid] =...
                   getMultiscaleBasis(solver.coarsegrid, A, 'useMEX', solver.useMEX, ...
                                                            'mexGrid', solver.mexGrid, ...
                                                            'basis',  solver.basis, ...
                                                            'iterations', solver.basisIterations, ...
                                                            'tolerance', solver.basisTolerance, ...
                                                            'type',   solver.prolongationType, ...
                                                            'useControlVolume', solver.controlVolumeRestriction, ...
                                                            'regularizeSys', true);
               solver.setupTime = toc(timer);
               dispif(solver.verbose, 'Basis constructed in %s.\n', formatTimeRange(solver.setupTime));
           end
       end
   end
end

function  [A, b, B, C, D, E, f, h] = reduceSystem(A, b, keepNum)
   [ix, jx, vx] = find(A);
   n = size(A, 2);
   keep = false(n, 1);
   keep(1:keepNum) = true;
   nk = keepNum;

   keepRow = keep(ix);
   keepCol = keep(jx);
   kb = keepRow & keepCol;
   B = sparse(ix(kb), jx(kb), vx(kb), nk, nk);

   kc = keepRow & ~keepCol;
   C = sparse(ix(kc), jx(kc) - nk, vx(kc), nk, n - nk);

   kd = ~keepRow & keepCol;
   D = sparse(ix(kd) - nk, jx(kd), vx(kd), n - nk, nk);

   ke = ~keepRow & ~keepCol;
   E = sparse(ix(ke) - nk, jx(ke) - nk, vx(ke), n - nk, n - nk);
   f = b(keep);
   h = b(~keep);
   
   [L, U] = lu(E);
   A = B - C*(U\(L\D));
   b = f - C*(U\(L\h));
end