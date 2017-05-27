using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GLSLRayTracer
{
    class Program
    {
        static void Main(string[] args)
        {
            using (Window window = new Window())
            {
                window.Run();
            }
        }
    }
}
